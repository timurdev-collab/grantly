import XCTest
@testable import EduT

final class ReleaseConfigurationTests: XCTestCase {
    func testAppEnvironmentValuesAreStable() {
        XCTAssertEqual(AppEnvironment.staging.rawValue, "staging")
        XCTAssertEqual(AppEnvironment.production.rawValue, "production")
    }

    func testScholarshipImportStatusDecoding() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "source_label": "Demo",
          "source_url": null,
          "status": "staged",
          "total_rows": 3,
          "insert_count": 1,
          "update_count": 1,
          "skip_count": 1,
          "error_count": 0,
          "committed_at": null,
          "rolled_back_at": null,
          "created_at": "2026-09-27T00:00:00Z"
        }
        """.data(using: .utf8)!

        let batch = try JSONDecoder().decode(
            ScholarshipImportBatch.self,
            from: json
        )

        XCTAssertEqual(batch.status, "staged")
        XCTAssertEqual(batch.totalRows, 3)
        XCTAssertEqual(batch.insertCount, 1)
    }
}
