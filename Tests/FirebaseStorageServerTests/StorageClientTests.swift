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
}
