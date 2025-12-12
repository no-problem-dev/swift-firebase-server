import Foundation

/// マクロ展開時のエラー
enum MacroError: Error, CustomStringConvertible {
    case requiresStruct
    case requiresEnum
    case missingCollectionId
    case invalidArgument(String)
    case message(String)

    var description: String {
        switch self {
        case .requiresStruct:
            return "@FirestoreModel can only be applied to struct declarations"
        case .requiresEnum:
            return "@FirestoreSchema, @Collection, @SubCollection can only be applied to enum declarations"
        case .missingCollectionId:
            return "@Collection and @SubCollection require a collection ID argument"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .message(let message):
            return message
        }
    }
}
