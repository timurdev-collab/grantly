import Foundation

enum SocialMediaUploadError: LocalizedError {
    case missingSession
    case invalidEndpoint
    case uploadCreationFailed(Int)
    case missingUploadLocation
    case chunkUploadFailed(Int)
    case invalidServerOffset
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Your session expired. Please sign in again."
        case .invalidEndpoint:
            return "Could not prepare the video upload."
        case .uploadCreationFailed:
            return "Could not start the video upload."
        case .missingUploadLocation:
            return "The upload server did not return an upload location."
        case .chunkUploadFailed:
            return "The video upload was interrupted."
        case .invalidServerOffset:
            return "The upload server returned an invalid progress position."
        case .unreadableFile:
            return "Could not read the selected video."
        }
    }
}

enum SocialMediaUploader {
    static let chunkSize = 6 * 1024 * 1024

    static func uploadResumable(
        fileURL: URL,
        path: String,
        contentType: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let session = try await supabase.auth.session
        let token = session.accessToken

        let values = try fileURL.resourceValues(
            forKeys: [.fileSizeKey]
        )
        guard let fileSize = values.fileSize else {
            throw SocialMediaUploadError.unreadableFile
        }

        guard let endpoint = resumableEndpoint() else {
            throw SocialMediaUploadError.invalidEndpoint
        }

        var createRequest = URLRequest(url: endpoint)
        createRequest.httpMethod = "POST"
        createRequest.setValue(
            "1.0.0",
            forHTTPHeaderField: "Tus-Resumable"
        )
        createRequest.setValue(
            String(fileSize),
            forHTTPHeaderField: "Upload-Length"
        )
        createRequest.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        createRequest.setValue(
            AppConfig.supabasePublishableKey,
            forHTTPHeaderField: "apikey"
        )
        createRequest.setValue(
            metadataHeader(
                path: path,
                contentType: contentType
            ),
            forHTTPHeaderField: "Upload-Metadata"
        )

        let (_, createResponse) = try await URLSession.shared.data(
            for: createRequest
        )

        guard let http = createResponse as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            let status = (createResponse as? HTTPURLResponse)?.statusCode ?? -1
            throw SocialMediaUploadError.uploadCreationFailed(status)
        }

        guard let location = http.value(
            forHTTPHeaderField: "Location"
        ),
        let uploadURL = URL(
            string: location,
            relativeTo: endpoint
        )?.absoluteURL
        else {
            throw SocialMediaUploadError.missingUploadLocation
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var offset = 0
        progress(0)

        while offset < fileSize {
            try Task.checkCancellation()

            try handle.seek(toOffset: UInt64(offset))
            let remaining = fileSize - offset
            let amount = min(chunkSize, remaining)

            guard let chunk = try handle.read(
                upToCount: amount
            ),
            !chunk.isEmpty
            else {
                throw SocialMediaUploadError.unreadableFile
            }

            var attempt = 0
            var completed = false

            while !completed {
                do {
                    var request = URLRequest(url: uploadURL)
                    request.httpMethod = "PATCH"
                    request.setValue(
                        "1.0.0",
                        forHTTPHeaderField: "Tus-Resumable"
                    )
                    request.setValue(
                        String(offset),
                        forHTTPHeaderField: "Upload-Offset"
                    )
                    request.setValue(
                        "application/offset+octet-stream",
                        forHTTPHeaderField: "Content-Type"
                    )
                    request.setValue(
                        "Bearer \(token)",
                        forHTTPHeaderField: "Authorization"
                    )
                    request.setValue(
                        AppConfig.supabasePublishableKey,
                        forHTTPHeaderField: "apikey"
                    )
                    request.httpBody = chunk

                    let (_, response) = try await URLSession.shared.data(
                        for: request
                    )

                    guard let patch = response as? HTTPURLResponse,
                          (200...299).contains(patch.statusCode)
                    else {
                        let status =
                            (response as? HTTPURLResponse)?.statusCode ?? -1
                        throw SocialMediaUploadError.chunkUploadFailed(status)
                    }

                    guard let serverOffsetValue = patch.value(
                        forHTTPHeaderField: "Upload-Offset"
                    ),
                    let serverOffset = Int(serverOffsetValue),
                    serverOffset > offset
                    else {
                        throw SocialMediaUploadError.invalidServerOffset
                    }

                    offset = serverOffset
                    completed = true
                    progress(
                        min(
                            1,
                            Double(offset) / Double(fileSize)
                        )
                    )
                } catch {
                    attempt += 1
                    guard attempt < 4 else {
                        throw error
                    }

                    let delay = UInt64(
                        [1, 3, 5][attempt - 1]
                    )
                    try await Task.sleep(
                        nanoseconds: delay * 1_000_000_000
                    )
                }
            }
        }
    }

    private static func resumableEndpoint() -> URL? {
        guard let host = AppConfig.supabaseURL.host else {
            return nil
        }

        let projectRef = host.split(separator: ".").first.map(String.init)
        guard let projectRef else {
            return nil
        }

        return URL(
            string:
                "https://\(projectRef).storage.supabase.co/" +
                "storage/v1/upload/resumable"
        )
    }

    private static func metadataHeader(
        path: String,
        contentType: String
    ) -> String {
        [
            metadataPair("bucketName", "social-media"),
            metadataPair("objectName", path),
            metadataPair("contentType", contentType),
            metadataPair("cacheControl", "3600")
        ]
        .joined(separator: ",")
    }

    private static func metadataPair(
        _ key: String,
        _ value: String
    ) -> String {
        let encoded = Data(value.utf8)
            .base64EncodedString()
        return "\(key) \(encoded)"
    }
}
