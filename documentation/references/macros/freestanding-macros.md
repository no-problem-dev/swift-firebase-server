# Freestanding Macro（独立型マクロ）

`#macroName()` の形式で呼び出す独立したマクロです。

## 概要

Freestanding Macroは宣言に付与せず、単独で使用するマクロです。2種類の役割があります：

| 役割 | 属性 | 用途 |
|------|------|------|
| Expression | `@freestanding(expression)` | 値を返す式を生成 |
| Declaration | `@freestanding(declaration)` | 宣言を生成 |

## Expression Macro

値を返す式を生成するマクロ。[SE-0382](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0382-expression-macros.md) で導入。

### 宣言

```swift
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(
    module: "MyMacros",
    type: "StringifyMacro"
)
```

### プロトコル

```swift
public protocol ExpressionMacro: FreestandingMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax
}
```

### 実装例

```swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            throw MacroError.missingArgument
        }

        return "(\(argument), \(literal: argument.description))"
    }
}
```

### 使用例

```swift
let result = #stringify(2 + 3)
// 展開後: (2 + 3, "2 + 3")
// result = (5, "2 + 3")
```

### 型チェック

Expression Macroは厳密な型チェックを受けます：

1. **引数の型チェック**: マクロ引数はパラメータ型に対して検証される
2. **ジェネリック推論**: 引数から型パラメータが推論される
3. **戻り値の検証**: 展開結果が宣言された戻り値型と一致するか検証される
4. **双方向推論**: 文脈からの型情報も考慮される

```swift
// 文脈による型推論
let x: (Double, String) = #stringify(1 + 2)
// 1と2はDoubleとして扱われる
```

## Declaration Macro

宣言を生成するマクロ。[SE-0397](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0397-freestanding-declaration-macros.md) で導入。

### 宣言

```swift
// 名前を生成しない場合
@freestanding(declaration)
public macro warning(_ message: String) = #externalMacro(
    module: "MyMacros",
    type: "WarningMacro"
)

// 名前を生成する場合
@freestanding(declaration, names: named(CodingKeys))
public macro generateCodingKeys() = #externalMacro(
    module: "MyMacros",
    type: "CodingKeysMacro"
)
```

### プロトコル

```swift
public protocol DeclarationMacro: FreestandingMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}
```

### 実装例

```swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct WarningMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let messageExpr = node.arguments.first?.expression,
              let segments = messageExpr.as(StringLiteralExprSyntax.self)?.segments,
              let message = segments.first?.as(StringSegmentSyntax.self)?.content.text
        else {
            throw MacroError.invalidArgument
        }

        // 警告を発行
        context.diagnose(Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
                message: message,
                diagnosticID: MessageID(domain: "WarningMacro", id: "warning"),
                severity: .warning
            )
        ))

        // 宣言は生成しない
        return []
    }
}
```

### 使用例

```swift
func process() {
    #warning("This function is not yet implemented")
    // コンパイル時に警告が表示される
}
```

### 使用可能な場所

Declaration Macroは宣言が許可される場所であればどこでも使用可能：

- 関数・クロージャ本体内
- トップレベル
- 型定義内

```swift
// トップレベル
#generateHelpers()

struct MyType {
    // 型定義内
    #generateCodingKeys()

    func method() {
        // 関数本体内
        #declareLocalHelper()
    }
}
```

## namesパラメータ

Declaration Macroが名前を生成する場合、`names:` パラメータで宣言が必要：

| 指定 | 説明 | 例 |
|------|------|-----|
| `named(foo)` | 固定名 | `names: named(CodingKeys)` |
| `prefixed(_)` | 接頭辞付き | `names: prefixed(_)` |
| `suffixed(_)` | 接尾辞付き | `names: suffixed(Impl)` |
| `arbitrary` | 任意の名前 | `names: arbitrary` |

```swift
// 固定名を生成
@freestanding(declaration, names: named(CodingKeys))
macro generateCodingKeys() = ...

// 複数の名前を生成
@freestanding(declaration, names: named(encode), named(decode))
macro generateCodable() = ...

// 任意の名前を生成可能
@freestanding(declaration, names: arbitrary)
macro generateFromTemplate(_ template: String) = ...
```

## 制限事項

1. **式マクロは値を返す必要がある**: `ExprSyntax` を返す
2. **宣言マクロは名前を事前宣言**: 生成する名前は `names:` で指定
3. **型情報へのアクセス制限**: マクロ展開時は完全な型情報を持たない

## 関連ドキュメント

- [Attached Macro](attached-macros.md) - 宣言に付与するマクロ
- [診断とエラー](diagnostics.md) - エラーメッセージの実装
- [SwiftSyntax API](swiftsyntax-api.md) - 構文木の操作
