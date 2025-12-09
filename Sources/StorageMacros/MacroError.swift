import Foundation

/// マクロ展開時のエラー
public enum StorageMacroError: Error, CustomStringConvertible {
    case requiresStruct
    case missingFolderName
    case missingObjectBaseName
    case invalidArgument(String)

    public var description: String {
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
