import Foundation
import Testing
@testable import FirestoreServer

/// Firestore エミュレーター（localhost:8080）に TCP 接続できるかを確認する。
/// この suite は実エミュレーターへの統合テストであり、未起動の環境では前提が成立しない。
private func firestoreEmulatorIsReachable() -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(8080).bigEndian
    addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return result == 0
}

/// set と update の違いを、実際に保存された内容で確かめる。
@Suite(
    "Firestore Emulator Write Tests",
    .enabled(if: firestoreEmulatorIsReachable(), "Firestore エミュレーター（localhost:8080）が起動していない")
)
struct FirestoreEmulatorWriteTests {

    private func makeClient() -> FirestoreClient {
        FirestoreClient(.emulator(projectId: "demo-verify"))
    }

    @Test("update leaves the fields it was not given alone")
    func updateKeepsOtherFields() async throws {
        let client = makeClient()
        let reference = try client.document("write-tests/\(UUID().uuidString)")

        try await client.setDocument(reference, fields: [
            "a": .string("A"),
            "b": .string("B"),
        ])

        try await client.updateDocument(reference, fields: ["a": .string("A2")])

        let stored = try await client.getDocument(reference)
        #expect(stored.fields["a"] == .string("A2"))
        #expect(stored.fields["b"] == .string("B"))

        try await client.deleteDocument(reference)
    }

    @Test("set drops the fields it was not given")
    func setReplacesTheDocument() async throws {
        let client = makeClient()
        let reference = try client.document("write-tests/\(UUID().uuidString)")

        try await client.setDocument(reference, fields: [
            "a": .string("A"),
            "b": .string("B"),
        ])

        try await client.setDocument(reference, fields: ["a": .string("A2")])

        let stored = try await client.getDocument(reference)
        #expect(stored.fields["a"] == .string("A2"))
        #expect(stored.fields["b"] == nil)

        try await client.deleteDocument(reference)
    }

    @Test("update refuses to create a document that is not there")
    func updateDoesNotCreate() async throws {
        let client = makeClient()
        let reference = try client.document("write-tests/\(UUID().uuidString)")

        await #expect(throws: FirestoreError.self) {
            try await client.updateDocument(reference, fields: ["a": .string("A")])
        }

        await #expect(throws: FirestoreError.self) {
            _ = try await client.getDocument(reference)
        }
    }

    @Test("set creates a document that is not there")
    func setCreates() async throws {
        let client = makeClient()
        let reference = try client.document("write-tests/\(UUID().uuidString)")

        try await client.setDocument(reference, fields: ["a": .string("A")])

        let stored = try await client.getDocument(reference)
        #expect(stored.fields["a"] == .string("A"))

        try await client.deleteDocument(reference)
    }

    @Test("cursors read as inclusive or exclusive the way the builder names them")
    func cursorsMatchTheirNames() async throws {
        let client = makeClient()
        let collectionId = "cursor-tests-\(UUID().uuidString.prefix(8))"
        let collection = client.collection(collectionId)

        struct Entry: Codable, Sendable, Equatable {
            let n: Int
        }

        for n in 1...5 {
            try await client.setDocument(collection.document("d\(n)"), data: Entry(n: n))
        }

        func run(_ configure: (Query<Entry>) -> Query<Entry>) async throws -> [Int] {
            let query = configure(collection.query(as: Entry.self).orderAscending(by: FieldPath("n")))
            return try await client.runQuery(query).map(\.n)
        }

        #expect(try await run { $0.start(at: .integer(3)) } == [3, 4, 5])
        #expect(try await run { $0.start(after: .integer(3)) } == [4, 5])
        #expect(try await run { $0.end(at: .integer(3)) } == [1, 2, 3])
        #expect(try await run { $0.end(before: .integer(3)) } == [1, 2])

        for n in 1...5 {
            try await client.deleteDocument(collection.document("d\(n)"))
        }
    }
}
