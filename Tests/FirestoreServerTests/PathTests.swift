import Testing
@testable import FirestoreServer

@Suite("Path Tests")
struct PathTests {
    @Test("CollectionPath - valid root collection")
    func collectionPathRoot() throws {
        let path = try CollectionPath("users")
        #expect(path.collectionId == "users")
        #expect(path.parent == nil)
        #expect(path.rawValue == "users")
    }

    @Test("CollectionPath - valid subcollection")
    func collectionPathSubcollection() throws {
        let path = try CollectionPath("users/abc/books")
        #expect(path.collectionId == "books")
        #expect(path.parent != nil)
        #expect(path.parent?.documentId == "abc")
        #expect(path.rawValue == "users/abc/books")
    }

    @Test("CollectionPath - invalid even segments")
    func collectionPathInvalid() {
        #expect(throws: PathError.self) {
            _ = try CollectionPath("users/abc")
        }
    }

    @Test("DocumentPath - valid document")
    func documentPathValid() throws {
        let path = try DocumentPath("users/abc")
        #expect(path.documentId == "abc")
        #expect(path.parent.collectionId == "users")
        #expect(path.rawValue == "users/abc")
    }

    @Test("DocumentPath - nested document")
    func documentPathNested() throws {
        let path = try DocumentPath("users/abc/books/xyz")
        #expect(path.documentId == "xyz")
        #expect(path.parent.collectionId == "books")
        #expect(path.rawValue == "users/abc/books/xyz")
    }

    @Test("DocumentPath - invalid odd segments")
    func documentPathInvalid() {
        #expect(throws: PathError.self) {
            _ = try DocumentPath("users")
        }
    }

    @Test("CollectionPath to DocumentPath chain")
    func pathChaining() throws {
        let collection = try CollectionPath("users")
        let document = collection.document("abc")
        let subcollection = document.collection("books")
        let nestedDocument = subcollection.document("xyz")

        #expect(document.rawValue == "users/abc")
        #expect(subcollection.rawValue == "users/abc/books")
        #expect(nestedDocument.rawValue == "users/abc/books/xyz")
    }
}
