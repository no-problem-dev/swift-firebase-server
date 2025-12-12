import Foundation

// MARK: - Key Encoding Strategy

/// キーのエンコーディング戦略
///
/// Swiftのプロパティ名をFirestoreのフィールド名に変換する方法を指定する。
///
/// 使用例:
/// ```swift
/// let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
/// // userId → user_id
/// // displayName → display_name
/// ```
public enum KeyEncodingStrategy: Sendable {
    /// デフォルト（変換なし）
    ///
    /// プロパティ名をそのままフィールド名として使用する。
    case useDefaultKeys

    /// camelCase → snake_case 変換
    ///
    /// Swiftの標準的な命名規則（camelCase）から
    /// Firestoreでよく使われるsnake_caseに変換する。
    ///
    /// 例:
    /// - `userId` → `user_id`
    /// - `createdAt` → `created_at`
    /// - `isActive` → `is_active`
    case convertToSnakeCase

    /// カスタム変換
    ///
    /// 独自のキー変換ロジックを指定する。
    case custom(@Sendable (String) -> String)

    /// キーを変換する
    /// - Parameter key: 元のキー
    /// - Returns: 変換後のキー
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

/// キーのデコーディング戦略
///
/// Firestoreのフィールド名をSwiftのプロパティ名に変換する方法を指定する。
///
/// 使用例:
/// ```swift
/// let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
/// // user_id → userId
/// // display_name → displayName
/// ```
public enum KeyDecodingStrategy: Sendable {
    /// デフォルト（変換なし）
    ///
    /// フィールド名をそのままプロパティ名として使用する。
    case useDefaultKeys

    /// snake_case → camelCase 変換
    ///
    /// Firestoreでよく使われるsnake_caseから
    /// Swiftの標準的な命名規則（camelCase）に変換する。
    ///
    /// 例:
    /// - `user_id` → `userId`
    /// - `created_at` → `createdAt`
    /// - `is_active` → `isActive`
    case convertFromSnakeCase

    /// カスタム変換
    ///
    /// 独自のキー変換ロジックを指定する。
    case custom(@Sendable (String) -> String)

    /// キーを変換する
    /// - Parameter key: 元のキー
    /// - Returns: 変換後のキー
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
    /// camelCase を snake_case に変換
    ///
    /// - Returns: snake_case形式の文字列
    ///
    /// 変換例:
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

                // アンダースコアを追加するケース:
                // 1. 先頭でない かつ
                // 2. 前の文字がアンダースコアでない かつ
                // 3. (前の文字が小文字である または (前の文字が大文字で次の文字が小文字である))
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

    /// snake_case を camelCase に変換
    ///
    /// - Returns: camelCase形式の文字列
    ///
    /// 変換例:
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
