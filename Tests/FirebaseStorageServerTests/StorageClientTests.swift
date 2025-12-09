import Foundation
import Testing
@testable import FirebaseStorageServer

@Suite("Storage Client Tests")
struct StorageClientTests {

    @Test("Client initialization - production")
    func clientInitializationProduction() {
        let client = StorageClient(
            projectId: "test-project",
            bucket: "test-bucket.appspot.com"
        )

        #expect(client.configuration.projectId == "test-project")
        #expect(client.configuration.bucket == "test-bucket.appspot.com")
        #expect(client.configuration.useEmulator == false)
    }

    @Test("Client initialization - emulator")
    func clientInitializationEmulator() {
        let config = StorageConfiguration.emulator(
            projectId: "test-project",
            bucket: "test-bucket"
        )
        let client = StorageClient(configuration: config)

        #expect(client.configuration.useEmulator == true)
    }

    @Test("Public URL generation")
    func publicURLGeneration() {
        let client = StorageClient(
            projectId: "test-project",
            bucket: "test-bucket.appspot.com"
        )

        let url = client.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "https://storage.googleapis.com/test-bucket.appspot.com/images/photo.jpg")
    }

    @Test("Public URL generation - with special characters")
    func publicURLGenerationSpecialCharacters() {
        let client = StorageClient(
            projectId: "test-project",
            bucket: "test-bucket"
        )

        let url = client.publicURL(for: "images/user123/photo name.jpg")
        #expect(url.absoluteString.contains("test-bucket"))
        // URLはスペースを%20にエンコードする
        #expect(url.absoluteString.contains("images/user123/photo%20name.jpg"))
    }

    @Test("Public URL generation - emulator")
    func publicURLGenerationEmulator() {
        let config = StorageConfiguration.emulator(
            projectId: "test-project",
            bucket: "test-bucket"
        )
        let client = StorageClient(configuration: config)

        let url = client.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "http://localhost:9199/test-bucket/images/photo.jpg")
    }

    @Test("Configuration is accessible")
    func configurationAccessible() {
        let config = StorageConfiguration(
            projectId: "my-project",
            bucket: "my-bucket",
            timeout: 90
        )
        let client = StorageClient(configuration: config)

        #expect(client.configuration.timeout == 90)
        #expect(client.configuration.projectId == "my-project")
    }
}
