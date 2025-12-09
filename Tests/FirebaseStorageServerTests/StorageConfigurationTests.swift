import Foundation
import Testing
@testable import FirebaseStorageServer

@Suite("Storage Configuration Tests")
struct StorageConfigurationTests {

    @Test("Production configuration")
    func productionConfiguration() {
        let config = StorageConfiguration(
            projectId: "test-project",
            bucket: "test-bucket.appspot.com"
        )

        #expect(config.projectId == "test-project")
        #expect(config.bucket == "test-bucket.appspot.com")
        #expect(config.baseURL.absoluteString == "https://storage.googleapis.com/storage/v1")
        #expect(config.uploadBaseURL.absoluteString == "https://storage.googleapis.com/upload/storage/v1")
        #expect(config.useEmulator == false)
        #expect(config.timeout == 60)
    }

    @Test("Emulator configuration")
    func emulatorConfiguration() {
        let config = StorageConfiguration.emulator(
            projectId: "test-project",
            bucket: "test-bucket"
        )

        #expect(config.projectId == "test-project")
        #expect(config.bucket == "test-bucket")
        #expect(config.useEmulator == true)
        #expect(config.baseURL.absoluteString == "http://localhost:9199/v0")
        #expect(config.uploadBaseURL.absoluteString == "http://localhost:9199/v0")
    }

    @Test("Emulator configuration with custom host and port")
    func emulatorConfigurationCustom() {
        let config = StorageConfiguration.emulator(
            projectId: "test-project",
            bucket: "test-bucket",
            host: "192.168.1.100",
            port: 9199
        )

        #expect(config.baseURL.absoluteString == "http://192.168.1.100:9199/v0")
        #expect(config.useEmulator == true)
    }

    @Test("Public URL - production")
    func publicURLProduction() {
        let config = StorageConfiguration(
            projectId: "test-project",
            bucket: "test-bucket.appspot.com"
        )

        let url = config.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "https://storage.googleapis.com/test-bucket.appspot.com/images/photo.jpg")
    }

    @Test("Public URL - emulator")
    func publicURLEmulator() {
        let config = StorageConfiguration.emulator(
            projectId: "test-project",
            bucket: "test-bucket"
        )

        let url = config.publicURL(for: "images/photo.jpg")
        #expect(url.absoluteString == "http://localhost:9199/test-bucket/images/photo.jpg")
    }

    @Test("Custom timeout")
    func customTimeout() {
        let config = StorageConfiguration(
            projectId: "test-project",
            bucket: "test-bucket",
            timeout: 120
        )

        #expect(config.timeout == 120)
    }
}
