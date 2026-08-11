import Foundation
import Testing
@testable import FirestoreServer

/// What a write actually puts on the wire.
///
/// A real ``FirestoreClient`` is pointed at a local stub server, so these assertions are about the
/// request the client sends, not about a builder it might call.
///
/// The semantics being pinned were measured against the Firestore emulator, over a document
/// holding fields `a` and `b`, patched with only `a`:
///
///   PATCH, no updateMask                          -> `b` is gone (a whole-document write)
///   PATCH, updateMask.fieldPaths=a                -> `b` survives
///   PATCH on a missing document, no precondition  -> the document is created
///   PATCH on a missing document, exists=true      -> 404, nothing created
@Suite("Document Write Tests")
struct DocumentWriteTests {

    struct Partial: Codable {
        let displayName: String
        let age: Int
    }

    private func withStubbedClient(
        respond: @escaping @Sendable (RecordedRequest) -> StubResponse = { _ in .ok },
        _ body: (FirestoreClient) async throws -> Void
    ) async throws -> [RecordedRequest] {
        let server = try await StubHTTPServer.start(respond: respond)

        let client = FirestoreClient(
            .emulator(projectId: "demo-project"),
            emulatorHost: "127.0.0.1",
            emulatorPort: server.port
        )

        // The server has to be stopped on the throwing path too, or its event loop group outlives
        // the test.
        var failure: Error?
        do {
            try await body(client)
        } catch {
            failure = error
        }

        let requests = server.requests
        await server.stop()

        if let failure { throw failure }
        return requests
    }

    // MARK: - Update

    @Test("updateDocument carries an updateMask covering exactly the encoded fields")
    func updateSendsUpdateMask() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")
            try await client.updateDocument(reference, data: Partial(displayName: "Alice", age: 30))
        }

        let request = try #require(requests.first)
        #expect(request.method == .PATCH)
        #expect(request.path.hasSuffix("/v1/projects/demo-project/databases/(default)/documents/users/abc"))
        #expect(request.queryValues(named: "updateMask.fieldPaths").sorted() == ["age", "displayName"])

        let fields = try #require(request.bodyJSON["fields"] as? [String: Any])
        #expect(Set(fields.keys) == ["displayName", "age"])
    }

    @Test("updateDocument asserts the document exists, so it never creates one")
    func updateSendsExistsPrecondition() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")
            try await client.updateDocument(reference, fields: ["status": .string("active")])
        }

        let request = try #require(requests.first)
        #expect(request.queryValues(named: "currentDocument.exists") == ["true"])
    }

    @Test("updateDocument masks only the fields it was given")
    func updateMasksOnlyGivenFields() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")
            try await client.updateDocument(reference, fields: [
                "status": .string("suspended"),
                "suspendedAt": .timestamp(Date(timeIntervalSince1970: 0)),
            ])
        }

        let request = try #require(requests.first)
        #expect(request.queryValues(named: "updateMask.fieldPaths").sorted() == ["status", "suspendedAt"])
    }

    @Test("updateDocument refuses an empty field map instead of replacing the document")
    func updateRejectsEmptyFields() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")

            await #expect(throws: FirestoreError.self) {
                try await client.updateDocument(reference, fields: [:])
            }
        }

        #expect(requests.isEmpty)
    }

    @Test("updateDocument quotes a field name that is not a plain identifier")
    func updateQuotesFieldPaths() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")
            try await client.updateDocument(reference, fields: ["home.address": .string("1 Main St")])
        }

        let request = try #require(requests.first)
        #expect(request.queryValues(named: "updateMask.fieldPaths") == ["`home.address`"])
    }

    // MARK: - Set

    @Test("setDocument carries no updateMask and no precondition, so it replaces and upserts")
    func setSendsWholeDocumentWrite() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")
            try await client.setDocument(reference, data: Partial(displayName: "Alice", age: 30))
        }

        let request = try #require(requests.first)
        #expect(request.method == .PATCH)
        #expect(request.queryValues(named: "updateMask.fieldPaths").isEmpty)
        #expect(request.queryValues(named: "currentDocument.exists").isEmpty)
        #expect(request.uri.contains("?") == false)
    }

    // MARK: - Coding Errors

    @Test("A document that does not fit the type fails as FirestoreError.decoding")
    func decodingFailureIsAFirestoreError() async throws {
        // `age` comes back as a string, which `Partial` cannot decode into an Int.
        let document = """
            {"name": "projects/demo-project/databases/(default)/documents/users/abc",
             "fields": {"displayName": {"stringValue": "Alice"}, "age": {"stringValue": "thirty"}}}
            """

        _ = try await withStubbedClient(respond: { _ in StubResponse(status: .ok, body: document) }) { client in
            let reference = try client.document("users/abc")

            do {
                _ = try await client.getDocument(reference, as: Partial.self)
                Issue.record("Expected FirestoreError.decoding")
            } catch let error as FirestoreError {
                guard case .decoding = error else {
                    Issue.record("Expected FirestoreError.decoding, got \(error)")
                    return
                }
            }
        }
    }

    @Test("A value that cannot encode fails as FirestoreError.encoding, before any request")
    func encodingFailureIsAFirestoreError() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/abc")

            do {
                // A bare integer is not a document: it encodes to a scalar, not a field map.
                try await client.setDocument(reference, data: 42)
                Issue.record("Expected FirestoreError.encoding")
            } catch let error as FirestoreError {
                guard case .encoding = error else {
                    Issue.record("Expected FirestoreError.encoding, got \(error)")
                    return
                }
            }
        }

        #expect(requests.isEmpty)
    }

    // MARK: - Query Value Encoding

    @Test("createDocument percent-encodes the document ID it puts in the query")
    func createEncodesDocumentId() async throws {
        let requests = try await withStubbedClient { client in
            let reference = try client.document("users/a&b c")
            try await client.createDocument(reference, fields: ["a": .string("A")])
        }

        let request = try #require(requests.first)
        #expect(request.uri.contains("documentId=a%26b%20c"))
        #expect(request.queryValues(named: "documentId") == ["a&b c"])
    }

    @Test("listDocuments percent-encodes the page token it puts in the query")
    func listEncodesPageToken() async throws {
        let requests = try await withStubbedClient(respond: { _ in StubResponse(status: .ok, body: "{}") }) { client in
            _ = try await client.listDocuments(in: client.collection("users"), pageToken: "a+b/c=")
        }

        // `+` in an unencoded query value is read as a space by Google's API frontend, so the
        // token has to travel escaped.
        let request = try #require(requests.first)
        #expect(request.uri.contains("pageToken=a%2Bb%2Fc%3D"))
    }
}
