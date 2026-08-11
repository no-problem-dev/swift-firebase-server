import Foundation
import Testing
@testable import FirebaseStorageServer
@testable import Internal

@Suite("Storage Client Tests")
struct StorageClientTests {

    @Test("Client initialization - explicit")
    func clientInitializationExplicit() {
        let client = StorageClient(
            .explicit(projectId: "test-project", token: "test-token"),
            bucket: "test-bucket.appspot.com"
        )

        #expect(client.configuration.projectId == "test-project")
        #expect(client.configuration.bucket == "test-bucket.appspot.com")
        #expect(client.configuration.useEmulator == false)
        #expect(client.token == "test-token")
    }

    @Test("Client initialization - emulator")
    func clientInitializationEmulator() {
        let client = StorageClient(
            .emulator(projectId: "test-project"),
            bucket: "test-bucket"
        )

        #expect(client.configuration.useEmulator == true)
        #expect(client.token == "owner")
    }

    @Test("Public URL generation")
    func publicURLGeneration() {
        let client = StorageClient(
            .explicit(projectId: "test-project", token: "token"),
            bucket: "test-bucket.appspot.com"
        )

        let url = client.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "https://storage.googleapis.com/test-bucket.appspot.com/images/photo.jpg")
    }

    @Test("Public URL generation - with special characters")
    func publicURLGenerationSpecialCharacters() {
        let client = StorageClient(
            .explicit(projectId: "test-project", token: "token"),
            bucket: "test-bucket"
        )

        let url = client.publicURL(for: "images/user123/photo name.jpg")
        #expect(url.absoluteString.contains("test-bucket"))
        #expect(url.absoluteString.contains("images/user123/photo%20name.jpg"))
    }

    @Test("Public URL generation - emulator")
    func publicURLGenerationEmulator() {
        let client = StorageClient(
            .emulator(projectId: "test-project"),
            bucket: "test-bucket"
        )

        let url = client.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "http://localhost:9199/test-bucket/images/photo.jpg")
    }

    // MARK: - Object Name Encoding
    //
    // The JSON API takes the object name as the single path segment of `b/{bucket}/o/{object}`,
    // so a nested name has to arrive as `images%2Fphoto.jpg`. See
    // https://cloud.google.com/storage/docs/request-endpoints#encoding

    let production = StorageConfiguration(projectId: "test-project", bucket: "test-bucket")

    @Test("Object URL - nested path is a single encoded segment")
    func objectURLEncodesSlashes() {
        let url = production.objectURL(for: "images/user123/photo.jpg")

        #expect(url == "https://storage.googleapis.com/storage/v1/b/test-bucket/o/images%2Fuser123%2Fphoto.jpg")
    }

    @Test("Download URL - nested path is a single encoded segment")
    func mediaURLEncodesSlashes() {
        let url = production.objectMediaURL(for: "images/user123/photo.jpg")

        #expect(url == "https://storage.googleapis.com/storage/v1/b/test-bucket/o/images%2Fuser123%2Fphoto.jpg?alt=media")
    }

    @Test("Upload URL - name query value is fully encoded")
    func uploadURLEncodesNameQueryValue() {
        let url = production.uploadURL(for: "a&b/c+d e.jpg")

        #expect(url == "https://storage.googleapis.com/upload/storage/v1/b/test-bucket/o?uploadType=media&name=a%26b%2Fc%2Bd%20e.jpg")
    }

    @Test("Object URL - reserved characters are escaped")
    func objectURLEncodesReservedCharacters() {
        let url = production.objectURL(for: "q?a#b&c+d")

        #expect(url.hasSuffix("/o/q%3Fa%23b%26c%2Bd"))
    }

    @Test("Object URL - unreserved characters are left alone")
    func objectURLKeepsUnreservedCharacters() {
        let url = production.objectURL(for: "a-b_c.d~e")

        #expect(url.hasSuffix("/o/a-b_c.d~e"))
    }

    // MARK: - Object Name Validation

    @Test("Upload rejects an empty object name before sending anything")
    func uploadRejectsEmptyPath() async throws {
        let client = try await StorageClient(.emulator(projectId: "test-project"), bucket: "test-bucket")

        await #expect(throws: StorageError.self) {
            _ = try await client.upload(data: Data(), path: "", contentType: "image/jpeg")
        }
    }

    @Test("Every path-taking call rejects the names Cloud Storage does not accept")
    func pathValidationRejectsInvalidNames() throws {
        for name in ["", ".", "..", "a\nb", "a\rb"] {
            #expect(throws: StorageError.self) {
                try StorageClient.validateObjectPath(name)
            }
        }
    }

    @Test("Path validation accepts an ordinary nested name")
    func pathValidationAcceptsNestedName() throws {
        try StorageClient.validateObjectPath("images/user123/photo.jpg")
        try StorageClient.validateObjectPath("a/../b")
    }
}
