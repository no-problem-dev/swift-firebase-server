# 診断とエラーハンドリング

マクロ実装でのエラー報告と診断メッセージの実装について説明します。

## 概要

マクロは2つの方法でエラーを報告できます：

1. **例外をスロー**: 展開関数からエラーをスロー
2. **診断を追加**: `context.diagnose()` でリッチな診断を出力

> **重要**: マクロが不正なSwiftコードを生成してコンパイラにエラーを任せるよりも、マクロ自身が分かりやすいエラーメッセージを出力すべきです。（参考: [Point-Free MacroTesting](https://github.com/pointfreeco/swift-macro-testing)）

## 例外をスロー

最もシンプルな方法。エラーはマクロ属性の位置に表示されます。

### 基本的なエラー定義

```swift
enum MacroError: Error, CustomStringConvertible {
    case notAStruct
    case missingArgument
    case invalidArgument(String)

    var description: String {
        switch self {
        case .notAStruct:
            return "@MyMacro can only be applied to structs"
        case .missingArgument:
            return "@MyMacro requires an argument"
        case .invalidArgument(let detail):
            return "Invalid argument: \(detail)"
        }
    }
}
```

### 使用例

```swift
public struct MyMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }
        // ...
    }
}
```

**結果**: エラーは `@MyMacro` 属性の位置に表示

```swift
@MyMacro  // error: @MyMacro can only be applied to structs
class NotAStruct { }
```

## DiagnosticMessage プロトコル

より詳細な診断情報を提供するための[DiagnosticMessage](https://github.com/swiftlang/swift-syntax)プロトコル：

```swift
public protocol DiagnosticMessage: Sendable {
    var message: String { get }
    var diagnosticID: MessageID { get }
    var severity: DiagnosticSeverity { get }
}
```

### 実装例

```swift
import SwiftDiagnostics

enum MyMacroDiagnostic: String, DiagnosticMessage {
    case notAStruct
    case missingCollectionName
    case invalidNesting

    var message: String {
        switch self {
        case .notAStruct:
            return "@MyMacro can only be applied to struct declarations"
        case .missingCollectionName:
            return "@Collection requires a collection name as the first argument"
        case .invalidNesting:
            return "@Collection cannot be nested more than 3 levels deep"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "MyMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .notAStruct, .missingCollectionName:
            return .error
        case .invalidNesting:
            return .warning
        }
    }
}
```

## context.diagnose()

`MacroExpansionContext.diagnose()` を使用してリッチな診断を出力：

### 基本的な使用

```swift
public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
) throws -> [DeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) else {
        context.diagnose(Diagnostic(
            node: node,
            message: MyMacroDiagnostic.notAStruct
        ))
        return []
    }
    // ...
}
```

### 位置を指定した診断

```swift
// 特定のノードを指定してエラー位置を変更
context.diagnose(Diagnostic(
    node: Syntax(someSpecificNode),  // エラーの位置
    message: MyMacroDiagnostic.missingCollectionName
))
```

## DiagnosticSeverity

| 重大度 | 説明 | 用途 |
|--------|------|------|
| `.error` | エラー | コンパイル失敗、修正必須 |
| `.warning` | 警告 | 問題の可能性、修正推奨 |
| `.note` | 注釈 | 追加情報、補足説明 |

```swift
var severity: DiagnosticSeverity {
    switch self {
    case .criticalError:
        return .error
    case .deprecatedUsage:
        return .warning
    case .additionalInfo:
        return .note
    }
}
```

## ハイライト

診断にコードのハイライトを追加：

```swift
context.diagnose(Diagnostic(
    node: node,
    message: MyMacroDiagnostic.invalidArgument,
    highlights: [Syntax(argumentNode)]  // ハイライトする範囲
))
```

## Notes（注釈）

追加の説明を付与：

```swift
// NoteMessage の定義
enum MyMacroNote: String, NoteMessage {
    case suggestedFix

    var message: String {
        switch self {
        case .suggestedFix:
            return "Consider using @OtherMacro instead"
        }
    }

    var fixItID: MessageID {
        MessageID(domain: "MyMacros", id: rawValue)
    }
}

// 使用
context.diagnose(Diagnostic(
    node: node,
    message: MyMacroDiagnostic.deprecatedUsage,
    notes: [
        Note(node: Syntax(node), message: MyMacroNote.suggestedFix)
    ]
))
```

## Fix-It

自動修正の提案を提供：

### FixItMessage の定義

```swift
enum MyMacroFixIt: String, FixItMessage {
    case addAsyncKeyword
    case removeAttribute

    var message: String {
        switch self {
        case .addAsyncKeyword:
            return "Add 'async' keyword"
        case .removeAttribute:
            return "Remove @MyMacro attribute"
        }
    }

    var fixItID: MessageID {
        MessageID(domain: "MyMacros", id: rawValue)
    }
}
```

### Fix-It の追加

```swift
context.diagnose(Diagnostic(
    node: node,
    message: MyMacroDiagnostic.notAsyncFunction,
    fixIts: [
        FixIt(
            message: MyMacroFixIt.addAsyncKeyword,
            changes: [
                .replace(
                    oldNode: Syntax(funcDecl.signature),
                    newNode: Syntax(newSignatureWithAsync)
                )
            ]
        )
    ]
))
```

### Fix-It の変更タイプ

```swift
// 置換
FixIt.Change.replace(oldNode: Syntax, newNode: Syntax)

// 削除
FixIt.Change.delete(oldNode: Syntax)

// 挿入（前）
FixIt.Change.insert(node: Syntax, before: AbsolutePosition)

// 挿入（後）
FixIt.Change.insert(node: Syntax, after: AbsolutePosition)
```

## 完全な例

```swift
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// 診断メッセージ
enum AddCompletionHandlerDiagnostic: String, DiagnosticMessage {
    case notAFunction
    case notAsync

    var message: String {
        switch self {
        case .notAFunction:
            return "@AddCompletionHandler can only be applied to functions"
        case .notAsync:
            return "@AddCompletionHandler requires an async function"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AddCompletionHandler", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}

// Fix-It メッセージ
enum AddCompletionHandlerFixIt: String, FixItMessage {
    case addAsync

    var message: String {
        switch self {
        case .addAsync:
            return "Add 'async'"
        }
    }

    var fixItID: MessageID {
        MessageID(domain: "AddCompletionHandler", id: rawValue)
    }
}

// マクロ実装
public struct AddCompletionHandlerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 関数かチェック
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: Syntax(declaration),
                message: AddCompletionHandlerDiagnostic.notAFunction
            ))
            return []
        }

        // asyncかチェック
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            // asyncでない場合、Fix-It付きでエラー
            let newEffectSpecifiers = FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async)
            )

            context.diagnose(Diagnostic(
                node: Syntax(funcDecl.signature),
                message: AddCompletionHandlerDiagnostic.notAsync,
                fixIts: [
                    FixIt(
                        message: AddCompletionHandlerFixIt.addAsync,
                        changes: [
                            // ... 修正内容
                        ]
                    )
                ]
            ))
            return []
        }

        // 正常なケース：completion handler版を生成
        // ...
    }
}
```

## ベストプラクティス

1. **早期検証**: 可能な限り早くエラーを検出・報告
2. **具体的なメッセージ**: 何が問題で、どう修正すべきか明確に
3. **正確な位置**: エラーの原因となる正確なノードを指定
4. **Fix-Itの提供**: 可能な場合は自動修正を提案
5. **警告の活用**: 致命的でない問題は警告として報告

## 参考リンク

- [SwiftDiagnostics](https://github.com/swiftlang/swift-syntax/tree/main/Sources/SwiftDiagnostics)
- [WWDC23: Expand on Swift macros](https://developer.apple.com/videos/play/wwdc2023/10167/)
- [Point-Free MacroTesting](https://github.com/pointfreeco/swift-macro-testing) - より良い診断テストツール

## 関連ドキュメント

- [テスト手法](testing.md) - 診断のテスト方法
- [SwiftSyntax API](swiftsyntax-api.md) - 構文木の操作
