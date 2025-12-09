import Foundation

/// マクロ展開時のエラー
public enum MacroError: Error, CustomStringConvertible {
    case requiresStruct
    case missingCollectionId
    case invalidArgument(String)

    public var description: String {
        switch self {
        case .requiresStruct:
            return "@FirestoreSchema, @Collection, @SubCollection can only be applied to struct declarations"
        case .missingCollectionId:
            return "@Collection and @SubCollection require a collection ID argument"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        }
    }
}
