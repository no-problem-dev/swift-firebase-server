import SwiftSyntaxMacrosTestSupport
import Testing

@testable import StorageMacros

@Suite("Storage Macros Tests")
struct StorageMacrosTests {

    @Test("StorageSchema macro generates basic properties")
    func storageSchemaMacroBasic() {
        assertMacroExpansion(
            """
            @StorageSchema
            struct AppStorage {
            }
            """,
            expandedSource: """
            struct AppStorage {

                public let client: StorageClient

                public init(client: StorageClient) {
                    self.client = client
                }
            }

            extension AppStorage: StorageSchemaProtocol, Sendable {
            }
            """,
            macros: ["StorageSchema": StorageSchemaMacro.self]
        )
    }

    @Test("StorageSchema macro with nested Folder")
    func storageSchemaMacroWithFolder() {
        assertMacroExpansion(
            """
            @StorageSchema
            struct AppStorage {
                @Folder("images")
                struct Images {
                }
            }
            """,
            expandedSource: """
            struct AppStorage {
                @Folder("images")
                struct Images {
                }

                public let client: StorageClient

                public init(client: StorageClient) {
                    self.client = client
                }

                public var images: Images {
                    Images(client: client, parentPath: nil)
                }
            }

            extension AppStorage: StorageSchemaProtocol, Sendable {
            }
            """,
            macros: ["StorageSchema": StorageSchemaMacro.self]
        )
    }

    @Test("Folder macro generates basic properties")
    func folderMacroBasic() {
        assertMacroExpansion(
            """
            @Folder("images")
            struct Images {
            }
            """,
            expandedSource: """
            struct Images {

                public static let folderName: String = "images"

                public let client: StorageClient

                public let parentPath: String?

                public init(client: StorageClient, parentPath: String?) {
                    self.client = client
                    self.parentPath = parentPath
                }
            }

            extension Images: StorageFolderProtocol, Sendable {
            }
            """,
            macros: ["Folder": FolderMacro.self]
        )
    }

    @Test("Folder macro with nested Object")
    func folderMacroWithObject() {
        assertMacroExpansion(
            """
            @Folder("users")
            struct Users {
                @Object("profile")
                struct Profile {
                }
            }
            """,
            expandedSource: """
            struct Users {
                @Object("profile")
                struct Profile {
                }

                public static let folderName: String = "users"

                public let client: StorageClient

                public let parentPath: String?

                public init(client: StorageClient, parentPath: String?) {
                    self.client = client
                    self.parentPath = parentPath
                }

                public func profile(_ objectId: String, _ ext: FileExtension) -> Profile {
                    Profile(client: client, parentPath: path, objectId: objectId, fileExtension: ext)
                }
            }

            extension Users: StorageFolderProtocol, Sendable {
            }
            """,
            macros: ["Folder": FolderMacro.self]
        )
    }

    @Test("Object macro generates basic properties")
    func objectMacroBasic() {
        assertMacroExpansion(
            """
            @Object("profile")
            struct Profile {
            }
            """,
            expandedSource: """
            struct Profile {

                public static let baseName: String = "profile"

                public let client: StorageClient

                public let parentPath: String

                public let objectId: String

                public let fileExtension: FileExtension

                public init(client: StorageClient, parentPath: String, objectId: String, fileExtension: FileExtension) {
                    self.client = client
                    self.parentPath = parentPath
                    self.objectId = objectId
                    self.fileExtension = fileExtension
                }
            }

            extension Profile: StorageObjectPathProtocol, Sendable {
            }
            """,
            macros: ["Object": ObjectMacro.self]
        )
    }
}
