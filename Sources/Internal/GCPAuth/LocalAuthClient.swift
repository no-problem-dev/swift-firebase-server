import Foundation

/// ローカル開発環境用の認証クライアント
///
/// gcloud CLI を使用してアクセストークンとプロジェクトIDを取得する。
/// 事前に `gcloud auth application-default login` の実行が必要。
struct LocalAuthClient: Sendable {
    /// gcloud CLI からアクセストークンを取得
    /// - Returns: アクセストークン
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    func fetchToken() async throws -> String {
        try await executeGcloudCommand(
            arguments: ["gcloud", "auth", "application-default", "print-access-token"],
            errorMapper: { message in
                GCPAuthError.gcloudExecutionFailed(message)
            },
            emptyErrorMessage: "Empty token returned"
        )
    }

    /// gcloud CLI からプロジェクトIDを取得
    /// - Returns: プロジェクトID
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    func fetchProjectId() async throws -> String {
        try await executeGcloudCommand(
            arguments: ["gcloud", "config", "get-value", "project"],
            errorMapper: { message in
                GCPAuthError.projectIdFetchFailed("gcloud: \(message)")
            },
            emptyErrorMessage: "Empty project ID returned. Run 'gcloud config set project <PROJECT_ID>'"
        )
    }

    /// gcloud CLI コマンドを実行
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
