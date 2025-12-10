import Foundation

/// ローカル開発環境用の認証クライアント
///
/// gcloud CLI を使用してアクセストークンを取得する。
/// 事前に `gcloud auth application-default login` の実行が必要。
struct LocalAuthClient: Sendable {
    /// gcloud CLI からアクセストークンを取得
    /// - Returns: アクセストークン
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    func fetchToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gcloud", "auth", "application-default", "print-access-token"]

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
                continuation.resume(throwing: GCPAuthError.gcloudExecutionFailed(errorMessage))
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let token = String(data: outputData, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines),
                !token.isEmpty
            else {
                continuation.resume(
                    throwing: GCPAuthError.gcloudExecutionFailed("Empty token returned"))
                return
            }

            continuation.resume(returning: token)
        }
    }
}
