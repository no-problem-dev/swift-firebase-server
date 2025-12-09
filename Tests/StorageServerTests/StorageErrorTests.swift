import Foundation
import Testing
@testable import StorageServer

@Suite("Storage Error Tests")
struct StorageErrorTests {

    @Test("Error from HTTP 404")
    func errorFromHTTP404() {
        let error = StorageError.fromHTTPResponse(
            statusCode: 404,
            body: nil,
            path: "images/photo.jpg"
        )

        let description = error.description
        #expect(description.contains("not found"))
    }

    @Test("Error from HTTP 401")
    func errorFromHTTP401() {
        let error = StorageError.fromHTTPResponse(
            statusCode: 401,
            body: "Unauthorized".data(using: .utf8),
            path: nil
        )

        let description = error.description
        #expect(description.contains("Unauthenticated"))
    }

    @Test("Error from HTTP 403")
    func errorFromHTTP403() {
        let error = StorageError.fromHTTPResponse(
            statusCode: 403,
            body: "Access denied".data(using: .utf8),
            path: nil
        )

        let description = error.description
        #expect(description.contains("Permission denied"))
    }

    @Test("File too large error")
    func fileTooLargeError() {
        let error = StorageError.fileTooLarge(size: 15_000_000, maxSize: 10_000_000)

        let description = error.description
        #expect(description.contains("too large"))
        #expect(description.contains("15000000"))
    }

    @Test("Invalid content type error")
    func invalidContentTypeError() {
        let error = StorageError.invalidContentType(contentType: "application/pdf")

        let description = error.description
        #expect(description.contains("Invalid content type"))
        #expect(description.contains("application/pdf"))
    }

    @Test("Invalid path error")
    func invalidPathError() {
        let error = StorageError.invalidPath(path: "../etc/passwd")

        let description = error.description
        #expect(description.contains("Invalid storage path"))
    }

    @Test("Convenience accessors")
    func convenienceAccessors() {
        let notFound = StorageError.notFound(path: "test/path")
        #expect(notFound.description.contains("not found"))

        let permissionDenied = StorageError.permissionDenied(message: "No access")
        #expect(permissionDenied.description.contains("Permission denied"))

        let unauthenticated = StorageError.unauthenticated(message: "No token")
        #expect(unauthenticated.description.contains("Unauthenticated"))

        let resourceExhausted = StorageError.resourceExhausted(message: "Rate limited")
        #expect(resourceExhausted.description.contains("exhausted"))
    }
}
