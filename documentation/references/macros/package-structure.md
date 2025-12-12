# マクロのパッケージ構成

Swift Macroを実装するためのパッケージ構成とプラグイン登録について説明します。

## ディレクトリ構造

```
MyMacroPackage/
├── Package.swift
├── Sources/
│   ├── MyMacros/                    # マクロ実装（CompilerPlugin）
│   │   ├── MyMacro.swift            # マクロ実装
│   │   ├── AnotherMacro.swift       # 別のマクロ実装
│   │   └── Plugin.swift             # プラグイン登録
│   │
│   └── MyLibrary/                   # 公開API（マクロ宣言）
│       ├── Macros.swift             # #externalMacro 宣言
│       └── Protocols.swift          # 関連プロトコル（任意）
│
└── Tests/
    └── MyMacrosTests/               # マクロテスト
        └── MyMacroTests.swift
```

## Package.swift

### 基本構成

```swift
// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MyMacroPackage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // 公開するライブラリ
        .library(
            name: "MyLibrary",
            targets: ["MyLibrary"]
        ),
    ],
    dependencies: [
        // swift-syntax 依存（必須）
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "600.0.0"
        ),
    ],
    targets: [
        // マクロ実装ターゲット（CompilerPlugin）
        .macro(
            name: "MyMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // 公開APIターゲット
        .target(
            name: "MyLibrary",
            dependencies: ["MyMacros"]
        ),

        // テストターゲット
        .testTarget(
            name: "MyMacrosTests",
            dependencies: [
                "MyMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
```

### swift-syntax のバージョン

| Swiftバージョン | swift-syntaxバージョン |
|----------------|----------------------|
| Swift 5.9 | 509.0.0 ~ |
| Swift 5.10 | 510.0.0 ~ |
| Swift 6.0 | 600.0.0 ~ |

> **Note**: Swiftのメジャーバージョンとswift-syntaxのバージョンは対応しています。

### 必要なProduct

| Product | 用途 |
|---------|------|
| `SwiftSyntax` | 構文木の型定義 |
| `SwiftSyntaxMacros` | マクロプロトコル定義 |
| `SwiftCompilerPlugin` | プラグイン登録 |
| `SwiftSyntaxBuilder` | 構文木の構築ヘルパー（任意） |
| `SwiftSyntaxMacrosTestSupport` | テスト用（テストターゲットのみ） |

## プラグイン登録（Plugin.swift）

マクロをコンパイラに登録するエントリーポイントです。

```swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        MemberwiseInitMacro.self,
        AddCompletionHandlerMacro.self,
        // 他のマクロを追加
    ]
}
```

### ポイント

- `@main` 属性でエントリーポイントを指定
- `CompilerPlugin` プロトコルに準拠
- `providingMacros` で全マクロ型を登録

## マクロ宣言（Macros.swift）

公開APIとしてマクロを宣言します。

```swift
// Sources/MyLibrary/Macros.swift

// Expression Macro
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(
    module: "MyMacros",
    type: "StringifyMacro"
)

// Declaration Macro
@freestanding(declaration, names: named(warning))
public macro warning(_ message: String) = #externalMacro(
    module: "MyMacros",
    type: "WarningMacro"
)

// Member Macro
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(
    module: "MyMacros",
    type: "MemberwiseInitMacro"
)

// 複数の役割を持つマクロ
@attached(member, names: arbitrary)
@attached(extension, conformances: Codable)
public macro Model() = #externalMacro(
    module: "MyMacros",
    type: "ModelMacro"
)
```

### #externalMacro の構成

```swift
#externalMacro(
    module: "MyMacros",      // .macroターゲット名
    type: "StringifyMacro"   // マクロ実装の型名
)
```

## マクロ実装

### 基本テンプレート

```swift
// Sources/MyMacros/StringifyMacro.swift

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

// エラー定義
enum MacroError: Error, CustomStringConvertible {
    case missingArgument

    var description: String {
        switch self {
        case .missingArgument:
            return "macro requires an argument"
        }
    }
}
```

### 複数役割を持つマクロ

```swift
// Sources/MyMacros/ModelMacro.swift

import SwiftSyntax
import SwiftSyntaxMacros

public struct ModelMacro: MemberMacro, ExtensionMacro {
    // MemberMacro の実装
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // メンバー生成ロジック
        return []
    }

    // ExtensionMacro の実装
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // extension生成ロジック
        return []
    }
}
```

## 関連プロトコル（任意）

マクロと連携するプロトコルを定義する場合：

```swift
// Sources/MyLibrary/Protocols.swift

public protocol ModelProtocol: Codable {
    static var tableName: String { get }
}
```

## 複数モジュール構成

大規模プロジェクトでの構成例：

```
MyPackage/
├── Package.swift
├── Sources/
│   ├── MyMacros/              # マクロ実装
│   │   └── ...
│   ├── MySchema/              # スキーマ関連（マクロ宣言＋プロトコル）
│   │   ├── Macros.swift
│   │   └── Protocols.swift
│   └── MyClient/              # クライアント実装（マクロを使用）
│       └── ...
└── Tests/
    ├── MyMacrosTests/
    └── MyClientTests/
```

```swift
// Package.swift（関連部分）
targets: [
    .macro(name: "MyMacros", dependencies: [...]),
    .target(name: "MySchema", dependencies: ["MyMacros"]),
    .target(name: "MyClient", dependencies: ["MySchema"]),
]
```

## ビルドとデバッグ

### ビルド

```bash
swift build
```

### テスト実行

```bash
swift test
```

### マクロ展開の確認

Xcodeで `Edit > Selection > Expand Macro` または右クリックメニューから展開結果を確認可能。

## 制限事項

1. **マクロターゲットは実行可能**: `.macro` ターゲットは実行可能なプラグインとしてビルドされる
2. **プラットフォーム依存**: マクロ自体はビルドマシンで実行されるが、展開結果は対象プラットフォームで動作する必要がある
3. **循環依存の禁止**: マクロ実装ターゲットは公開ターゲットに依存できない

## 関連ドキュメント

- [Freestanding Macro](freestanding-macros.md) - 独立型マクロの詳細
- [Attached Macro](attached-macros.md) - 付与型マクロの詳細
- [テスト手法](testing.md) - マクロのテスト方法
