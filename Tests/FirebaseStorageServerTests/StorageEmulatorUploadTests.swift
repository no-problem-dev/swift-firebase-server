import Foundation
import Testing
import AsyncHTTPClient
import NIOCore
@testable import FirebaseStorageServer
@testable import Internal

/// Storage エミュレーター（localhost:9199）に TCP 接続できるかを確認する。
/// この suite は実エミュレーターへの統合テストであり、未起動の環境では前提が成立しない。
private func storageEmulatorIsReachable() -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(9199).bigEndian
    addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return result == 0
}

@Suite(
    "Storage Emulator Upload Tests",
    .enabled(if: storageEmulatorIsReachable(), "Firebase Storage エミュレーター（localhost:9199）が起動していない")
)
struct StorageEmulatorUploadTests {

    /// エミュレーターへの実際のアップロードテスト
    /// 実際のHTTPレスポンスをキャプチャして内容を確認
    @Test("Emulator upload - raw response capture")
    func emulatorUploadRawResponse() async throws {
        // エミュレーターが起動していることを前提とする（suite の enabled 条件で検査済み）
        let client = try await StorageClient(
            .emulator(projectId: "reading-memory"),
            bucket: "reading-memory.appspot.com"
        )

        // テスト用の小さな画像データを作成
        let testData = "test image data".data(using: .utf8)!
        let testPath = "test/upload-test-\(UUID().uuidString).jpg"

        print("📤 Uploading to emulator...")
        print("URL: \(client.configuration.uploadBaseURL)/b/\(client.configuration.bucket)/o?uploadType=media&name=\(testPath)")

        do {
            let result = try await client.upload(
                data: testData,
                path: testPath,
                contentType: "image/jpeg"
            )

            print("✅ Upload succeeded!")
            print("Bucket: \(result.bucket)")
            print("Name: \(result.name)")
            print("Size: \(result.size)")

        } catch let error as StorageError {
            print("❌ Upload failed with StorageError:")
            print("Error: \(error)")
            print("Error description: \(error.description)")

            // エラー詳細を出力
            switch error {
            case .api(let apiError):
                print("API Error: \(apiError)")
            default:
                print("Other error: \(error)")
            }

            throw error
        } catch {
            print("❌ Upload failed with unknown error:")
            print("Error: \(error)")
            throw error
        }
    }

    /// 直接HTTPリクエストを送信してレスポンスを確認
    @Test("Emulator upload - direct HTTP request")
    func emulatorDirectHTTPRequest() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        // HTTPClient は shutdown せずに deinit すると fatalError でプロセスごと落ちる。
        // リクエストが throw する経路でも必ず一度だけ shutdown してから結果を返す。
        var failure: Error?
        do {
            try await runDirectHTTPRequest(httpClient)
        } catch {
            failure = error
        }
        try await httpClient.shutdown()
        if let failure { throw failure }
    }

    private func runDirectHTTPRequest(_ httpClient: HTTPClient) async throws {
        let bucket = "reading-memory.appspot.com"
        let path = "test/direct-upload-\(UUID().uuidString).jpg"
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "http://localhost:9199/v0/b/\(bucket)/o?uploadType=media&name=\(encodedPath)"

        print("📤 Direct HTTP POST to: \(url)")

        let testData = "test image data".data(using: .utf8)!

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer owner")
        request.headers.add(name: "Content-Type", value: "image/jpeg")
        request.headers.add(name: "Content-Length", value: String(testData.count))
        request.body = .bytes(ByteBuffer(data: testData))

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        print("📥 Response status: \(response.status.code)")
        print("📥 Response headers:")
        for (name, value) in response.headers {
            print("  \(name): \(value)")
        }

        let bodyData = body.toData()
        print("📥 Response body size: \(bodyData.count) bytes")

        // レスポンスボディをUTF-8文字列として表示
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📥 Response body (text):")
            print(bodyString)
        } else {
            print("📥 Response body is not UTF-8 text")
        }

        // JSONとしてパースを試みる
        do {
            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            print("📥 Response body (JSON):")
            print(json ?? "nil")

            if let json = json {
                print("📥 JSON keys: \(json.keys.joined(separator: ", "))")

                // StorageObject.fromJSONが期待するフィールドをチェック
                let expectedFields = ["bucket", "name", "size"]
                for field in expectedFields {
                    if json[field] != nil {
                        print("✅ Field '\(field)' exists")
                    } else {
                        print("❌ Field '\(field)' is MISSING")
                    }
                }
            }
        } catch {
            print("❌ Failed to parse as JSON: \(error)")
        }

        #expect(response.status == .ok, "Expected 200 OK response from emulator")
    }
}

// ByteBuffer extension for Data conversion
extension ByteBuffer {
    func toData() -> Data {
        Data(self.readableBytesView)
    }
}
