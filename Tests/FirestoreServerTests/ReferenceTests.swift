import Testing
@testable import FirestoreServer

@Suite("Reference Tests")
struct ReferenceTests {
    let database = DatabasePath(projectId: "test-project", databaseId: "(default)")

    @Test("DatabasePath - documents path")
    func databasePath() {
        #expect(database.documentsPath == "projects/test-project/databases/(default)/documents")
    }

    @Test("CollectionReference - root collection")
    func collectionReferenceRoot() throws {
        let path = try CollectionPath("users")
        let ref = CollectionReference(database: database, path: path)

        #expect(ref.collectionId == "users")
        #expect(ref.restParent == "projects/test-project/databases/(default)/documents")
        #expect(ref.restCollectionId == "users")
        #expect(ref.restPath == "projects/test-project/databases/(default)/documents/users")
    }

    @Test("CollectionReference - subcollection")
    func collectionReferenceSubcollection() throws {
        let path = try CollectionPath("users/abc/books")
        let ref = CollectionReference(database: database, path: path)

        #expect(ref.collectionId == "books")
        #expect(ref.restParent == "projects/test-project/databases/(default)/documents/users/abc")
        #expect(ref.restCollectionId == "books")
    }

    @Test("DocumentReference - rest name")
    func documentReferenceRestName() throws {
        let path = try DocumentPath("users/abc")
        let ref = DocumentReference(database: database, path: path)

        #expect(ref.documentId == "abc")
        #expect(ref.restName == "projects/test-project/databases/(default)/documents/users/abc")
    }

    @Test("Reference chaining")
    func referenceChaining() throws {
        let path = try CollectionPath("users")
        let usersRef = CollectionReference(database: database, path: path)
        let userRef = usersRef.document("abc")
        let booksRef = userRef.collection("books")
        let bookRef = booksRef.document("xyz")

        #expect(userRef.restName == "projects/test-project/databases/(default)/documents/users/abc")
        #expect(booksRef.restPath == "projects/test-project/databases/(default)/documents/users/abc/books")
        #expect(bookRef.restName == "projects/test-project/databases/(default)/documents/users/abc/books/xyz")
    }
}
