import Foundation

/// Reads the access token and project ID from the gcloud CLI on a developer machine.
///
/// Requires `gcloud auth application-default login` to have been run; no service account key
/// file is read, so `GOOGLE_APPLICATION_CREDENTIALS` has no effect here. Every call spawns a
/// process and waits for it, which is slow enough that the result is worth caching.
struct LocalAuthClient: Sendable {
    /// Runs `gcloud auth application-default print-access-token` and returns its output.
    ///
    /// The token comes from the application default credentials, not from whatever account
    /// `gcloud auth login` set, and gcloud reports no expiry with it.
    ///
    /// - Throws: `GCPAuthError.gcloudNotAvailable` if gcloud cannot be launched, or
    ///   `.gcloudExecutionFailed` if it exits non-zero or prints nothing.
    func fetchToken() async throws -> String {
        try await executeGcloudCommand(
            arguments: ["gcloud", "auth", "application-default", "print-access-token"],
            errorMapper: { message in
                GCPAuthError.gcloudExecutionFailed(message)
            },
            emptyErrorMessage: "Empty token returned"
        )
    }

    /// Runs `gcloud config get-value project` and returns its output.
    ///
    /// Reports whichever project the active gcloud configuration points at, which is not
    /// necessarily the one the application default credentials were issued for.
    ///
    /// - Throws: `GCPAuthError.gcloudNotAvailable` if gcloud cannot be launched, or
    ///   `.projectIdFetchFailed` if it exits non-zero or no project is set, in which case the
    ///   message tells the caller to run `gcloud config set project`.
    func fetchProjectId() async throws -> String {
        try await executeGcloudCommand(
            arguments: ["gcloud", "config", "get-value", "project"],
            errorMapper: { message in
                GCPAuthError.projectIdFetchFailed("gcloud: \(message)")
            },
            emptyErrorMessage: "Empty project ID returned. Run 'gcloud config set project <PROJECT_ID>'"
        )
    }

    /// Runs a command through `/usr/bin/env` and returns its standard output, trimmed.
    ///
    /// Blocks the calling thread in `waitUntilExit` rather than suspending, and reads both pipes
    /// only after the process has exited, so a command that filled a pipe buffer would deadlock.
    /// The gcloud invocations here print a single short line.
    ///
    /// - Parameters:
    ///   - arguments: The command and its arguments, the executable name first.
    ///   - errorMapper: Builds the error to throw from a failure message, so each caller can
    ///     report the failure as its own case.
    ///   - emptyErrorMessage: The message to map when the command succeeds but prints nothing.
    private func executeGcloudCommand(
        arguments: [String],
        errorMapper: @Sendable (String) -> GCPAuthError,
        emptyErrorMessage: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GCPAuthError.gcloudNotAvailable)
                return
            }

            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage =
                    String(data: errorData, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines) ?? "Unknown error"
                continuation.resume(throwing: errorMapper(errorMessage))
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let result = String(data: outputData, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines),
                !result.isEmpty
            else {
                continuation.resume(throwing: errorMapper(emptyErrorMessage))
                return
            }

            continuation.resume(returning: result)
        }
    }
}
