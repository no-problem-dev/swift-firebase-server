# Swift Macro リファレンス

Swift 5.9で導入されたマクロシステムの包括的なリファレンスです。

## 概要

Swift Macroは、コンパイル時にソースコードを変換・生成する機能です。ボイラープレートコードの削減、型安全なDSLの構築、コンパイル時検証などに活用できます。

## 目次

### マクロの種類

| ドキュメント | 説明 |
|-------------|------|
| [Freestanding Macro](freestanding-macros.md) | `#` で呼び出す独立型マクロ（Expression, Declaration） |
| [Attached Macro](attached-macros.md) | `@` で宣言に付与するマクロ（Member, Peer, Accessor等） |

### 実装ガイド

| ドキュメント | 説明 |
|-------------|------|
| [パッケージ構成](package-structure.md) | Package.swift、ディレクトリ構造、プラグイン登録 |
| [SwiftSyntax API](swiftsyntax-api.md) | 構文木の操作、主要な型とプロトコル |
| [診断とエラー](diagnostics.md) | エラーメッセージ、警告、Fix-Itの実装 |
| [テスト手法](testing.md) | assertMacroExpansion、診断テスト |

## マクロの分類

### Freestanding Macro（独立型）

`#macroName()` の形式で呼び出すマクロ。

| 役割 | 属性 | プロトコル | 用途 |
|------|------|-----------|------|
| Expression | `@freestanding(expression)` | `ExpressionMacro` | 値を返す式を生成 |
| Declaration | `@freestanding(declaration)` | `DeclarationMacro` | 宣言を生成 |

### Attached Macro（付与型）

`@MacroName` の形式で宣言に付与するマクロ。

| 役割 | 属性 | プロトコル | 用途 |
|------|------|-----------|------|
| Peer | `@attached(peer)` | `PeerMacro` | 同じスコープに宣言を追加 |
| Member | `@attached(member)` | `MemberMacro` | 型にメンバーを追加 |
| MemberAttribute | `@attached(memberAttribute)` | `MemberAttributeMacro` | メンバーに属性を追加 |
| Accessor | `@attached(accessor)` | `AccessorMacro` | プロパティにアクセサを追加 |
| Extension | `@attached(extension)` | `ExtensionMacro` | extensionを生成 |
| Body | `@attached(body)` | `BodyMacro` | 関数本体を生成 |

## クイックリファレンス

### マクロ宣言の基本形

```swift
// Freestanding（独立型）
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(
    module: "MyMacros",
    type: "StringifyMacro"
)

// Attached（付与型）
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(
    module: "MyMacros",
    type: "MemberwiseInitMacro"
)
```

### 必須依存関係

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
]
```

## Swift Evolution 提案

| 提案 | タイトル | 内容 |
|------|---------|------|
| [SE-0382](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0382-expression-macros.md) | Expression Macros | 式マクロの導入 |
| [SE-0389](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md) | Attached Macros | 付与型マクロの導入 |
| [SE-0397](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0397-freestanding-declaration-macros.md) | Freestanding Declaration Macros | 宣言マクロの導入 |
| [SE-0402](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0402-extension-macros.md) | Extension Macros | extensionマクロの導入 |
| [SE-0407](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0407-member-macro-conformances.md) | Member Macro Conformances | memberマクロの適合情報 |
| [SE-0415](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0415-function-body-macros.md) | Function Body Macros | 関数本体マクロの導入 |

## 公式リソース

- [WWDC23: Write Swift macros](https://developer.apple.com/videos/play/wwdc2023/10166/) - マクロの基礎
- [WWDC23: Expand on Swift macros](https://developer.apple.com/videos/play/wwdc2023/10167/) - 高度なマクロ実装
- [swift-syntax リポジトリ](https://github.com/swiftlang/swift-syntax) - SwiftSyntaxライブラリ
- [Swift Macros ビジョン](https://github.com/swiftlang/swift-evolution/blob/main/visions/macros.md) - マクロの設計思想
