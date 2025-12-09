import Testing
import Foundation
@testable import FirebaseAuthServer

@Suite("Auth Configuration Tests")
struct AuthConfigurationTests {

    // MARK: - Production Configuration

    @Test("Production config has correct project ID")
    func testProductionProjectId() {
        let config = AuthConfiguration(projectId: "my-firebase-project")

        #expect(config.projectId == "my-firebase-project")
    }

    @Test("Production config has default timeout")
    func testProductionDefaultTimeout() {
        let config = AuthConfiguration(projectId: "my-project")

        #expect(config.timeout == 30)
    }

    @Test("Production config has custom timeout")
    func testProductionCustomTimeout() {
        let config = AuthConfiguration(projectId: "my-project", timeout: 60)

        #expect(config.timeout == 60)
    }

    @Test("Production config is not emulator mode")
    func testProductionNotEmulator() {
        let config = AuthConfiguration(projectId: "my-project")

        #expect(config.useEmulator == false)
        #expect(config.emulatorHost == nil)
        #expect(config.emulatorPort == nil)
    }

    @Test("Expected issuer is correctly constructed")
    func testExpectedIssuer() {
        let config = AuthConfiguration(projectId: "my-firebase-project")

        #expect(config.expectedIssuer == "https://securetoken.google.com/my-firebase-project")
    }

    @Test("Expected audience equals project ID")
    func testExpectedAudience() {
        let config = AuthConfiguration(projectId: "my-firebase-project")

        #expect(config.expectedAudience == "my-firebase-project")
    }

    // MARK: - Emulator Configuration

    @Test("Emulator config enables emulator mode")
    func testEmulatorMode() {
        let config = AuthConfiguration.emulator(projectId: "my-project")

        #expect(config.useEmulator == true)
    }

    @Test("Emulator config has default host and port")
    func testEmulatorDefaults() {
        let config = AuthConfiguration.emulator(projectId: "my-project")

        #expect(config.emulatorHost == "localhost")
        #expect(config.emulatorPort == AuthConfiguration.defaultEmulatorPort)
    }

    @Test("Emulator config accepts custom host and port")
    func testEmulatorCustomHostPort() {
        let config = AuthConfiguration.emulator(
            projectId: "my-project",
            host: "192.168.1.100",
            port: 9199
        )

        #expect(config.emulatorHost == "192.168.1.100")
        #expect(config.emulatorPort == 9199)
    }

    @Test("Emulator config has custom timeout")
    func testEmulatorCustomTimeout() {
        let config = AuthConfiguration.emulator(
            projectId: "my-project",
            timeout: 120
        )

        #expect(config.timeout == 120)
    }

    // MARK: - Public Keys URL

    @Test("Public keys URL is Google endpoint")
    func testPublicKeysURL() {
        let expectedURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

        #expect(AuthConfiguration.publicKeysURL.absoluteString == expectedURL)
    }
}
