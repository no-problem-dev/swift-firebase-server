import Foundation

/// A failure raised while expanding `@StorageSchema`, `@Folder`, or `@Object`.
///
/// Throwing one of these turns into a compile-time diagnostic carrying its ``description``.
enum StorageMacroError: Error, CustomStringConvertible {
    case requiresStruct
    case missingFolderName
    case missingObjectBaseName
    case invalidArgument(String)

    var description: String {
        switch self {
        case .requiresStruct:
            return "@StorageSchema, @Folder, @Object can only be applied to struct declarations"
        case .missingFolderName:
            return "@Folder requires a folder name argument"
        case .missingObjectBaseName:
            return "@Object requires a base name argument"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        }
    }
}
