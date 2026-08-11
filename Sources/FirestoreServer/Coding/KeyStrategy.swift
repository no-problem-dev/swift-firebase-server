import Foundation

// MARK: - Key Encoding Strategy

/// How a Swift property name becomes a Firestore field name.
///
/// ```swift
/// let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
/// // userId → user_id
/// // displayName → display_name
/// ```
public enum KeyEncodingStrategy: Sendable {
    /// Writes the property name unchanged.
    case useDefaultKeys

    /// Rewrites camelCase into snake_case.
    ///
    /// Runs of capitals stay together, so the conversion is lossy and does not round-trip back
    /// through `convertFromSnakeCase`:
    /// - `userId` → `user_id`
    /// - `createdAt` → `created_at`
    /// - `isActive` → `is_active`
    case convertToSnakeCase

    /// Applies a closure of your own to every key.
    case custom(@Sendable (String) -> String)

    /// Applies the strategy to one key.
    /// - Parameter key: The Swift property name.
    /// - Returns: The Firestore field name to write.
    func encode(_ key: String) -> String {
        switch self {
        case .useDefaultKeys:
            return key
        case .convertToSnakeCase:
            return key.convertToSnakeCase()
        case .custom(let transform):
            return transform(key)
        }
    }
}

// MARK: - Key Decoding Strategy

/// How a Firestore field name is matched against a Swift property name.
///
/// A field whose name already matches the property exactly always wins, whichever strategy is
/// in force; the strategy only decides how the remaining names are resolved.
///
/// ```swift
/// let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
/// // user_id → userId
/// // display_name → displayName
/// ```
public enum KeyDecodingStrategy: Sendable {
    /// Matches field names to property names verbatim.
    case useDefaultKeys

    /// Rewrites snake_case into camelCase.
    ///
    /// The conversion is not the exact inverse of `convertToSnakeCase`, because a run of
    /// capitals cannot be recovered:
    /// - `user_id` → `userId`
    /// - `created_at` → `createdAt`
    /// - `is_https_enabled` → `isHttpsEnabled`
    case convertFromSnakeCase

    /// Applies a closure of your own to every key.
    ///
    /// The decoder cannot invert the closure, so it resolves each property by transforming
    /// every field name in the document until one matches.
    case custom(@Sendable (String) -> String)

    /// Applies the strategy to one key.
    /// - Parameter key: The Firestore field name.
    /// - Returns: The Swift property name it stands for.
    func decode(_ key: String) -> String {
        switch self {
        case .useDefaultKeys:
            return key
        case .convertFromSnakeCase:
            return key.convertFromSnakeCase()
        case .custom(let transform):
            return transform(key)
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Rewrites camelCase into snake_case.
    ///
    /// A run of capitals is kept as one word and only broken before its last letter, and an
    /// underscore already in the string is never doubled:
    /// - `userId` → `user_id`
    /// - `displayName` → `display_name`
    /// - `createdAt` → `created_at`
    /// - `isHTTPSEnabled` → `is_https_enabled`
    /// - `URLString` → `url_string`
    func convertToSnakeCase() -> String {
        guard !isEmpty else { return self }

        let chars = Array(self)
        var result = ""

        for (index, char) in chars.enumerated() {
            if char.isUppercase {
                let isFirst = index == 0
                let previousIsUppercase = index > 0 && chars[index - 1].isUppercase
                let nextIsLowercase = index + 1 < chars.count && chars[index + 1].isLowercase
                let previousIsUnderscore = index > 0 && chars[index - 1] == "_"

                // Insert an underscore when:
                // 1. this is not the first character, and
                // 2. the previous character is not already an underscore, and
                // 3. the previous character is lowercase, or it is uppercase and the next one
                //    is lowercase (the last capital of a run, as in URLString)
                if !isFirst && !previousIsUnderscore {
                    if !previousIsUppercase || nextIsLowercase {
                        result.append("_")
                    }
                }
                result.append(char.lowercased())
            } else {
                result.append(char)
            }
        }

        return result
    }

    /// Rewrites snake_case into camelCase.
    ///
    /// A string without an underscore is returned untouched, and each underscore is dropped in
    /// favour of capitalising the character after it — so a leading underscore capitalises the
    /// first letter and a trailing one simply disappears:
    /// - `user_id` → `userId`
    /// - `display_name` → `displayName`
    /// - `created_at` → `createdAt`
    /// - `is_https_enabled` → `isHttpsEnabled`
    func convertFromSnakeCase() -> String {
        guard contains("_") else { return self }

        var result = ""
        var capitalizeNext = false

        for char in self {
            if char == "_" {
                capitalizeNext = true
            } else if capitalizeNext {
                result.append(char.uppercased())
                capitalizeNext = false
            } else {
                result.append(char)
            }
        }

        return result
    }
}
