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


    // MARK: - Segment Validation
    //
    // Measured against the Firestore emulator, PATCH on each of these paths comes back 400:
    //   ids/__weird__  -> Resource id "__weird__" is invalid because it is reserved.
    //   __sys__/x      -> Collection id "__sys__" is invalid because it is reserved.
    //   ids/.          -> contains a resource id "."
    //   ids/..         -> contains a resource id ".."
    //   ids/<1600 a>   -> The key path element name is longer than 1500 bytes.

    @Test("Reserved, dotted, and over-long IDs are refused before a request is built")
    func pathRejectsInvalidSegments() {
        let invalid = [
            "ids/__weird__",
            "__sys__/x",
            "ids/.",
            "ids/..",
            "ids/" + String(repeating: "a", count: 1501),
        ]

        for path in invalid {
            #expect(throws: PathError.self, "expected \(path) to be refused") {
                _ = try ResourcePath(path)
            }
        }
    }

    @Test("The refusal names the offending segment")
    func pathErrorCarriesTheSegment() throws {
        do {
            _ = try DocumentPath("users/__id__")
            Issue.record("Expected PathError.invalidCharacters")
        } catch let error as PathError {
            #expect(error == .invalidCharacters("__id__"))
        }
    }

    @Test("Ordinary IDs, including ones with dots and underscores, are accepted")
    func pathAcceptsOrdinarySegments() throws {
        _ = try DocumentPath("users/abc.123")
        _ = try DocumentPath("users/_private")
        _ = try DocumentPath("users/__")
        _ = try CollectionPath("users/abc/books")
        _ = try DocumentPath("users/" + String(repeating: "a", count: 1500))
    }
}
