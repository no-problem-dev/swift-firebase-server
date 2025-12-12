# SwiftSyntax API リファレンス

マクロ実装で使用する主要なSwiftSyntax APIについて説明します。

## 概要

[SwiftSyntax](https://github.com/swiftlang/swift-syntax) はSwiftソースコードを解析・操作するためのライブラリです。マクロ実装では、入力の構文木を読み取り、新しい構文木を生成します。

## 主要な型

### 構文ノード（Syntax Nodes）

構文木を構成するノードの主要な型：

| 型 | 説明 | 例 |
|---|------|-----|
| `DeclSyntax` | 宣言 | struct, class, func, var |
| `ExprSyntax` | 式 | リテラル, 関数呼び出し, 演算 |
| `StmtSyntax` | 文 | if, for, return |
| `TypeSyntax` | 型 | Int, String, [T] |
| `PatternSyntax` | パターン | 識別子, タプル |
| `AttributeSyntax` | 属性 | @available, @MainActor |

### 宣言型の詳細

| 型 | 対応するSwift構文 |
|---|-----------------|
| `StructDeclSyntax` | `struct Name { }` |
| `ClassDeclSyntax` | `class Name { }` |
| `EnumDeclSyntax` | `enum Name { }` |
| `FunctionDeclSyntax` | `func name() { }` |
| `VariableDeclSyntax` | `var/let name: Type` |
| `InitializerDeclSyntax` | `init() { }` |
| `ExtensionDeclSyntax` | `extension Type { }` |
| `ProtocolDeclSyntax` | `protocol Name { }` |

### 式型の詳細

| 型 | 対応するSwift構文 |
|---|-----------------|
| `StringLiteralExprSyntax` | `"text"` |
| `IntegerLiteralExprSyntax` | `42` |
| `BooleanLiteralExprSyntax` | `true`, `false` |
| `FunctionCallExprSyntax` | `foo(arg: value)` |
| `MemberAccessExprSyntax` | `obj.property` |
| `IdentifierExprSyntax` | `variableName` |
| `ArrayExprSyntax` | `[1, 2, 3]` |
| `DictionaryExprSyntax` | `["key": value]` |

## マクロ固有の型

### FreestandingMacroExpansionSyntax

Freestanding Macro（`#macroName()`）の構文を表現：

```swift
// #stringify(x + y) の構文
node.macroName        // "stringify"
node.arguments        // (x + y)
node.trailingClosure  // トレイリングクロージャ（あれば）
```

### AttributeSyntax

Attached Macro（`@MacroName`）の属性構文を表現：

```swift
// @MemberwiseInit の構文
node.attributeName    // "MemberwiseInit"
node.arguments        // 引数（あれば）
```

### DeclGroupSyntax

型定義（struct, class, enum, extension等）のプロトコル：

```swift
declaration.memberBlock.members  // メンバー一覧
declaration.attributes           // 属性一覧
declaration.modifiers            // 修飾子（public, private等）
```

## MacroExpansionContext

マクロ展開時のコンテキスト情報を提供：

```swift
public protocol MacroExpansionContext {
    // ユニークな名前を生成
    func makeUniqueName(_ name: String) -> TokenSyntax

    // 診断を出力
    func diagnose(_ diagnostic: Diagnostic)

    // ソースの位置情報
    var lexicalContext: [Syntax] { get }
}
```

### makeUniqueName

衝突しない一意の識別子を生成：

```swift
let uniqueName = context.makeUniqueName("storage")
// → "__macro_local_7storagefMu_" のような一意の名前

let varDecl: DeclSyntax = "var \(uniqueName): Int = 0"
```

### diagnose

警告やエラーを出力（詳細は[診断とエラー](diagnostics.md)参照）：

```swift
context.diagnose(Diagnostic(
    node: node,
    message: MyDiagnostic.invalidUsage
))
```

## 構文木の読み取り

### 型キャスト

`as()` メソッドで特定の型に変換：

```swift
// DeclSyntaxProtocol → StructDeclSyntax
if let structDecl = declaration.as(StructDeclSyntax.self) {
    // structDeclとして操作
}

// 失敗時はnil
guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
    throw MacroError.notAFunction
}
```

### is() による型チェック

```swift
if declaration.is(StructDeclSyntax.self) {
    // 構造体の場合
}
```

### メンバーの走査

```swift
// 型のメンバーを走査
for member in declaration.memberBlock.members {
    if let varDecl = member.decl.as(VariableDeclSyntax.self) {
        // 変数宣言を処理
        for binding in varDecl.bindings {
            if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                print("Property: \(name)")
            }
        }
    }
}
```

### 属性の検出

```swift
// 特定の属性を持つか確認
let hasAttribute = declaration.attributes.contains { attr in
    attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Observable"
}

// 属性の引数を取得
if let attr = node.as(AttributeSyntax.self),
   let args = attr.arguments?.as(LabeledExprListSyntax.self) {
    for arg in args {
        print("Label: \(arg.label?.text ?? "none"), Value: \(arg.expression)")
    }
}
```

### 文字列リテラルの取得

```swift
// @Macro("value") から "value" を取得
guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first?.expression.as(StringLiteralExprSyntax.self),
      let segment = firstArg.segments.first?.as(StringSegmentSyntax.self)
else {
    throw MacroError.invalidArgument
}

let value = segment.content.text  // "value"
```

## 構文木の生成

### 文字列補間（推奨）

SwiftSyntaxBuilderの文字列補間で簡潔に生成：

```swift
import SwiftSyntaxBuilder

// 単純な宣言
let varDecl: DeclSyntax = "var count: Int = 0"

// 補間を使用
let name = "myProperty"
let type = "String"
let propertyDecl: DeclSyntax = "var \(raw: name): \(raw: type)"

// リテラルの埋め込み
let message = "Hello"
let stringExpr: ExprSyntax = "\(literal: message)"  // "Hello"（エスケープ済み）
```

### raw vs literal

| 補間 | 用途 | 例 |
|------|------|-----|
| `\(raw: value)` | そのまま埋め込む | 識別子、型名 |
| `\(literal: value)` | リテラルとして埋め込む | 文字列、数値 |
| `\(expr)` | Syntax型をそのまま埋め込む | 既存ノード |

```swift
let name = "test"
let expr: ExprSyntax = someExpression

// raw: そのまま埋め込み
let decl1: DeclSyntax = "var \(raw: name) = 0"
// → var test = 0

// literal: 文字列リテラルとして埋め込み
let decl2: DeclSyntax = "var name = \(literal: name)"
// → var name = "test"

// Syntax型はそのまま
let decl3: DeclSyntax = "var x = \(expr)"
// → var x = <someExpression>
```

### 複雑な構文の生成

```swift
// 複数行の生成
let initDecl: DeclSyntax = """
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    """

// 条件分岐を含む生成
let properties = ["name", "age"]
let assignments = properties.map { "self.\($0) = \($0)" }.joined(separator: "\n")

let body: DeclSyntax = """
    init(\(raw: properties.map { "\($0): String" }.joined(separator: ", "))) {
        \(raw: assignments)
    }
    """
```

### SyntaxBuilder API（明示的な構築）

より細かい制御が必要な場合：

```swift
import SwiftSyntaxBuilder

let funcDecl = FunctionDeclSyntax(
    name: "myFunction",
    signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
                FunctionParameterSyntax(
                    firstName: .identifier("value"),
                    type: IdentifierTypeSyntax(name: "Int")
                )
            }
        ),
        returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "String")
        )
    ),
    body: CodeBlockSyntax {
        ReturnStmtSyntax(
            expression: StringLiteralExprSyntax(content: "result")
        )
    }
)
```

## トークン操作

### trimmed

空白やコメントを除去：

```swift
let typeName = type.trimmedDescription  // 前後の空白なし
```

### TokenSyntax

個別のトークンを操作：

```swift
// 識別子トークン
let identifier = TokenSyntax.identifier("myName")

// キーワードトークン
let letKeyword = TokenSyntax.keyword(.let)

// 既存トークンの取得
let funcName = funcDecl.name  // TokenSyntax
```

## よくあるパターン

### プロパティ一覧の抽出

```swift
func extractStoredProperties(from declaration: some DeclGroupSyntax) -> [(name: String, type: String)] {
    declaration.memberBlock.members.compactMap { member -> (String, String)? in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              varDecl.bindings.count == 1,
              let binding = varDecl.bindings.first,
              binding.accessorBlock == nil,  // computed propertyを除外
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type.trimmedDescription
        else {
            return nil
        }
        return (name, type)
    }
}
```

### 型名の取得

```swift
func getTypeName(from declaration: some DeclGroupSyntax) -> String? {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
        return structDecl.name.text
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
        return classDecl.name.text
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
        return enumDecl.name.text
    }
    return nil
}
```

### ネストした構造体の検出

```swift
func findNestedStructs(in declaration: some DeclGroupSyntax, withAttribute attrName: String) -> [StructDeclSyntax] {
    declaration.memberBlock.members.compactMap { member -> StructDeclSyntax? in
        guard let structDecl = member.decl.as(StructDeclSyntax.self) else {
            return nil
        }

        let hasAttribute = structDecl.attributes.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == attrName
        }

        return hasAttribute ? structDecl : nil
    }
}
```

## 参考リンク

- [swift-syntax リポジトリ](https://github.com/swiftlang/swift-syntax)
- [SwiftSyntax ドキュメント](https://swiftinit.org/docs/swift-syntax)
- [WWDC23: Write Swift macros](https://developer.apple.com/videos/play/wwdc2023/10166/)

## 関連ドキュメント

- [Freestanding Macro](freestanding-macros.md) - 独立型マクロ
- [Attached Macro](attached-macros.md) - 付与型マクロ
- [診断とエラー](diagnostics.md) - エラーメッセージの実装
