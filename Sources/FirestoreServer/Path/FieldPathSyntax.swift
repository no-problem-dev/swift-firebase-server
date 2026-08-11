import Foundation

/// Writes a field name the way Firestore's field path grammar expects it.
///
/// A field path is a dot-separated list of segments, so a field name that is not a plain
/// identifier — one holding a dot, a space, a backtick, or anything else outside
/// `[A-Za-z_][A-Za-z_0-9]*` — has to be backtick-quoted, or the server reads it as several
/// segments or rejects it outright.
enum FieldPathSyntax {
    /// Returns the field name as one field path segment, quoted only when it has to be.
    static func quoted(_ fieldName: String) -> String {
        guard needsQuoting(fieldName) else {
            return fieldName
        }

        let escaped = fieldName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return "`\(escaped)`"
    }

    private static func needsQuoting(_ fieldName: String) -> Bool {
        guard let first = fieldName.first else {
            // An empty name cannot be written unquoted
            return true
        }

        let isIdentifierStart = first.isASCII && (first.isLetter || first == "_")
        guard isIdentifierStart else {
            return true
        }

        return fieldName.contains { character in
            !(character.isASCII && (character.isLetter || character.isNumber || character == "_"))
        }
    }
}
