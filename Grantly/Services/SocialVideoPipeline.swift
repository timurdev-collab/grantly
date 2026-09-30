import AVFoundation
import CoreTransferable
import Foundation

struct SocialVideoTransfer: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty
                ? "mov"
                : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString.lowercased())
                .appendingPathExtension(ext)

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(
                at: received.file,
                to: destination
            )

            return Self(url: destination)
        }
    }
}

enum SocialVideoUploadError: LocalizedError {
    case invalidProjectURL
    case invalidUploadLocation
    case createFailed(Int)
    case patchFailed(Int)
    case missingOffset
    case compressionFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidProjectURL:
            return L10n.string("Could not prepare the video upload.")
        case .invalidUploadLocation:
            return L10n.string("The video upload could not be started.")
        case .createFailed:
            return L10n.string("The video upload could not be started.")
        case .patchFailed:
            return L10n.string("The video upload was interrupted. Please try again.")
        case .missingOffset:
            return L10n.string("The video upload was interrupted. Please try again.")
        case .compressionFailed:
            return L10n.string("Could not prepare this video for upload.")
        case .fileTooLarge:
            return L10n.string("Please choose a video smaller than 250 MB.")
        }
    }
}

enum SocialVideoPipeline {
    static let maxUploadBytes: Int64 = 250 * 1024 * 1024
    private static let chunkSize = 6 * 1024 * 1024

    static func compress(_ inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw SocialVideoUploadError.compressionFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            try? FileManager.default.removeItem(at: outputURL)
            throw exporter.error ?? SocialVideoUploadError.compressionFailed
        }

        let values = try outputURL.resourceValues(
            forKeys: [.fileSizeKey]
        )
        let fileSize = Int64(values.fileSize ?? 0)

        guard fileSize > 0, fileSize <= maxUploadBytes else {
            try? FileManager.default.removeItem(at: outputURL)
            throw SocialVideoUploadError.fileTooLarge
        }

        return outputURL
    }

    static func upload(
        fileURL: URL,
        contentType: String = "video/mp4",
        progress: @escaping @Sendable (Double) async -> Void
    ) async throws -> String {
        let session = try await supabase.auth.session
        let userId = session.user.id
        let objectPath =
            "\(userId.uuidString.lowercased())/" +
            "\(UUID().uuidString.lowercased()).mp4"

        let values = try fileURL.resourceValues(
            forKeys: [.fileSizeKey]
        )
        let totalBytes = Int64(values.fileSize ?? 0)

        guard totalBytes > 0, totalBytes <= maxUploadBytes else {
            throw SocialVideoUploadError.fileTooLarge
        }

        let endpoint = try resumableEndpoint()
        var createRequest = URLRequest(url: endpoint)
        createRequest.httpMethod = "POST"
        createRequest.setValue(
            "Bearer \(session.accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        createRequest.setValue(
            AppConfig.supabasePublishableKey,
            forHTTPHeaderField: "apikey"
        )
        createRequest.setValue(
            "1.0.0",
            forHTTPHeaderField: "Tus-Resumable"
        )
        createRequest.setValue(
            "\(totalBytes)",
            forHTTPHeaderField: "Upload-Length"
        )
        createRequest.setValue(
            uploadMetadata(
                bucket: "social-media",
                objectPath: objectPath,
                contentType: contentType
            ),
            forHTTPHeaderField: "Upload-Metadata"
        )
        createRequest.setValue(
            "true",
            forHTTPHeaderField: "x-upsert"
        )

        let (_, createResponse) = try await URLSession.shared.data(
            for: createRequest
        )

        guard let createHTTP = createResponse as? HTTPURLResponse,
              (200...299).contains(createHTTP.statusCode) else {
            throw SocialVideoUploadError.createFailed(
                (createResponse as? HTTPURLResponse)?.statusCode ?? -1
            )
        }

        guard let location = createHTTP.value(
            forHTTPHeaderField: "Location"
        ) else {
            throw SocialVideoUploadError.invalidUploadLocation
        }

        let uploadURL: URL
        if let absolute = URL(string: location),
           absolute.scheme != nil {
            uploadURL = absolute
        } else if let relative = URL(
            string: location,
            relativeTo: endpoint
        )?.absoluteURL {
            uploadURL = relative
        } else {
            throw SocialVideoUploadError.invalidUploadLocation
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var offset: Int64 = 0
        await progress(0)

        while offset < totalBytes {
            try Task.checkCancellation()

            let data = try handle.read(
                upToCount: chunkSize
            ) ?? Data()

            guard !data.isEmpty else { break }

            var patchRequest = URLRequest(url: uploadURL)
            patchRequest.httpMethod = "PATCH"
            patchRequest.setValue(
                "Bearer \(session.accessToken)",
                forHTTPHeaderField: "Authorization"
            )
            patchRequest.setValue(
                AppConfig.supabasePublishableKey,
                forHTTPHeaderField: "apikey"
            )
            patchRequest.setValue(
                "1.0.0",
                forHTTPHeaderField: "Tus-Resumable"
            )
            patchRequest.setValue(
                "\(offset)",
                forHTTPHeaderField: "Upload-Offset"
            )
            patchRequest.setValue(
                "application/offset+octet-stream",
                forHTTPHeaderField: "Content-Type"
            )

            let (_, patchResponse) = try await URLSession.shared.upload(
                for: patchRequest,
                from: data
            )

            guard let patchHTTP = patchResponse as? HTTPURLResponse,
                  (200...299).contains(patchHTTP.statusCode) else {
                throw SocialVideoUploadError.patchFailed(
                    (patchResponse as? HTTPURLResponse)?.statusCode ?? -1
                )
            }

            if let offsetValue = patchHTTP.value(
                forHTTPHeaderField: "Upload-Offset"
            ),
               let serverOffset = Int64(offsetValue) {
                offset = serverOffset
            } else {
                offset += Int64(data.count)
            }

            await progress(
                min(1, Double(offset) / Double(totalBytes))
            )
        }

        guard offset >= totalBytes else {
            throw SocialVideoUploadError.missingOffset
        }

        return objectPath
    }

    private static func resumableEndpoint() throws -> URL {
        guard let host = AppConfig.supabaseURL.host else {
            throw SocialVideoUploadError.invalidProjectURL
        }

        let directHost: String
        if host.hasSuffix(".supabase.co") {
            let projectRef = String(
                host.dropLast(".supabase.co".count)
            )
            directHost = "\(projectRef).storage.supabase.co"
        } else {
            directHost = host
        }

        guard let url = URL(
            string:
                "https://\(directHost)/storage/v1/upload/resumable"
        ) else {
            throw SocialVideoUploadError.invalidProjectURL
        }

        return url
    }

    private static func uploadMetadata(
        bucket: String,
        objectPath: String,
        contentType: String
    ) -> String {
        [
            ("bucketName", bucket),
            ("objectName", objectPath),
            ("contentType", contentType),
            ("cacheControl", "3600")
        ]
        .map { key, value in
            let encoded = Data(value.utf8)
                .base64EncodedString()
            return "\(key) \(encoded)"
        }
        .joined(separator: ",")
    }
}
