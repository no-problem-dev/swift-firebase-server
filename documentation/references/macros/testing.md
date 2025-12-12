# マクロのテスト手法

Swift Macroのテスト方法について説明します。

## 概要

マクロのテストには主に2つのアプローチがあります：

1. **assertMacroExpansion**: Apple公式のSwiftSyntaxテストツール
2. **swift-macro-testing**: [Point-Free](https://github.com/pointfreeco/swift-macro-testing)によるサードパーティツール

## セットアップ

### Package.swift

```swift
.testTarget(
    name: "MyMacrosTests",
    dependencies: [
        "MyMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
    ]
)
```

### テストファイルの基本構造

```swift
import SwiftSyntaxMacrosTestSupport
import XCTest

// テスト対象のマクロをインポート
@testable import MyMacros

final class MyMacroTests: XCTestCase {
    // テストケース
}
```

## assertMacroExpansion

### 基本的な使用法

```swift
func testStringifyMacro() throws {
    assertMacroExpansion(
        """
        #stringify(a + b)
        """,
        expandedSource: """
        (a + b, "a + b")
        """,
        macros: ["stringify": StringifyMacro.self]
    )
}
```

### パラメータ

| パラメータ | 型 | 説明 |
|-----------|---|------|
| `_` | `String` | 入力ソースコード |
| `expandedSource` | `String` | 期待される展開結果 |
| `diagnostics` | `[DiagnosticSpec]` | 期待される診断 |
| `macros` | `[String: Macro.Type]` | テスト対象のマクロ |
| `applyFixIts` | `[String]?` | 適用するFix-It |
| `fixedSource` | `String?` | Fix-It適用後のソース |

### Attached Macro のテスト

```swift
func testMemberwiseInitMacro() throws {
    assertMacroExpansion(
        """
        @MemberwiseInit
        struct User {
            let name: String
            let age: Int
        }
        """,
        expandedSource: """
        struct User {
            let name: String
            let age: Int

            init(name: String, age: Int) {
                self.name = name
                self.age = age
            }
        }
        """,
        macros: ["MemberwiseInit": MemberwiseInitMacro.self]
    )
}
```

### 複数役割を持つマクロのテスト

```swift
func testModelMacro() throws {
    assertMacroExpansion(
        """
        @Model
        struct User {
            var name: String
        }
        """,
        expandedSource: """
        struct User {
            var name: String

            init(name: String) {
                self.name = name
            }
        }

        extension User: Codable {
        }
        """,
        macros: ["Model": ModelMacro.self]
    )
}
```

## 診断のテスト

### DiagnosticSpec

診断を検証するための構造体：

```swift
DiagnosticSpec(
    id: MessageID?,           // 診断ID（任意）
    message: String,          // エラーメッセージ
    line: Int,                // 行番号
    column: Int,              // 列番号
    severity: DiagnosticSeverity,  // 重大度
    highlight: String?,       // ハイライト範囲（任意）
    notes: [NoteSpec],        // 注釈（任意）
    fixIts: [FixItSpec]       // Fix-It（任意）
)
```

### エラーのテスト

```swift
func testNotAStruct() throws {
    assertMacroExpansion(
        """
        @MemberwiseInit
        class NotAStruct {
        }
        """,
        expandedSource: """
        class NotAStruct {
        }
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@MemberwiseInit can only be applied to structs",
                line: 1,
                column: 1,
                severity: .error
            )
        ],
        macros: ["MemberwiseInit": MemberwiseInitMacro.self]
    )
}
```

### 警告のテスト

```swift
func testDeprecatedUsage() throws {
    assertMacroExpansion(
        """
        @OldMacro
        struct Test { }
        """,
        expandedSource: """
        struct Test { }
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@OldMacro is deprecated, use @NewMacro instead",
                line: 1,
                column: 1,
                severity: .warning
            )
        ],
        macros: ["OldMacro": OldMacro.self]
    )
}
```

### 複数の診断のテスト

```swift
func testMultipleDiagnostics() throws {
    assertMacroExpansion(
        """
        @MyMacro
        class Invalid {
            var noType
        }
        """,
        expandedSource: """
        class Invalid {
            var noType
        }
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@MyMacro can only be applied to structs",
                line: 1,
                column: 1,
                severity: .error
            ),
            DiagnosticSpec(
                message: "Property 'noType' has no type annotation",
                line: 3,
                column: 5,
                severity: .error
            )
        ],
        macros: ["MyMacro": MyMacro.self]
    )
}
```

## Fix-It のテスト

### FixItSpec

```swift
FixItSpec(message: String)  // Fix-Itのメッセージを指定
```

### Fix-It 適用のテスト

```swift
func testAddAsyncFixIt() throws {
    assertMacroExpansion(
        """
        @AddCompletionHandler
        func fetchData() -> Data { }
        """,
        expandedSource: """
        func fetchData() -> Data { }
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@AddCompletionHandler requires an async function",
                line: 1,
                column: 1,
                severity: .error,
                fixIts: [
                    FixItSpec(message: "Add 'async'")
                ]
            )
        ],
        macros: ["AddCompletionHandler": AddCompletionHandlerMacro.self],
        applyFixIts: ["Add 'async'"],
        fixedSource: """
        @AddCompletionHandler
        func fetchData() async -> Data { }
        """
    )
}
```

## swift-macro-testing（サードパーティ）

[Point-Free](https://www.pointfree.co/blog/posts/114-a-new-tool-for-testing-macros-in-swift)による改良されたテストツール。診断をソースコードにインラインで表示します。

### 利点

- 診断がソースコード内に直接表示される
- 行・列番号を手動で指定する必要がない
- より直感的なテスト記述

### セットアップ

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.0"),
]

.testTarget(
    name: "MyMacrosTests",
    dependencies: [
        "MyMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
    ]
)
```

### 使用例

```swift
import MacroTesting
import XCTest

final class MyMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            macros: ["MemberwiseInit": MemberwiseInitMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testExpansion() {
        assertMacro {
            """
            @MemberwiseInit
            struct User {
                let name: String
            }
            """
        } expansion: {
            """
            struct User {
                let name: String

                init(name: String) {
                    self.name = name
                }
            }
            """
        }
    }

    func testDiagnostic() {
        assertMacro {
            """
            @MemberwiseInit
            class NotAStruct { }
            """
        } diagnostics: {
            """
            @MemberwiseInit
            ┬───────────────
            ╰─ 🛑 @MemberwiseInit can only be applied to structs
            class NotAStruct { }
            """
        }
    }
}
```

## テストのベストプラクティス

### 1. 正常系と異常系の両方をテスト

```swift
// 正常系
func testValidUsage() { ... }

// 異常系
func testInvalidType() { ... }
func testMissingArgument() { ... }
func testInvalidNesting() { ... }
```

### 2. エッジケースのテスト

```swift
// 空の構造体
func testEmptyStruct() { ... }

// 多数のプロパティ
func testManyProperties() { ... }

// ネストした型
func testNestedTypes() { ... }

// ジェネリクス
func testGenericType() { ... }
```

### 3. 診断の網羅的テスト

```swift
// 全てのエラーケースをテスト
func testAllErrorCases() {
    // 各エラーパターンに対してテストを作成
}

// Fix-Itの動作確認
func testFixItApplication() { ... }
```

### 4. 複雑な入力のテスト

```swift
func testComplexInput() throws {
    assertMacroExpansion(
        """
        @Schema
        public struct AppSchema {
            @Collection("users", model: User.self)
            struct Users {
                @Collection("posts", model: Post.self)
                struct Posts { }
            }
        }
        """,
        expandedSource: """
        // 期待される複雑な展開結果
        """,
        macros: ["Schema": SchemaMacro.self, "Collection": CollectionMacro.self]
    )
}
```

### 5. ホワイトスペースに注意

展開結果の比較では空白やインデントが重要です。期待値を正確に記述してください。

```swift
// インデントを正確に
expandedSource: """
struct User {
    let name: String

    init(name: String) {
        self.name = name
    }
}
"""
```

## デバッグ

### Xcodeでマクロ展開を確認

1. マクロを使用しているコードを選択
2. 右クリック → "Expand Macro" を選択
3. 展開結果を確認

### テスト失敗時

`assertMacroExpansion` は期待値と実際の展開結果の差分を表示します。差分を確認して期待値を修正してください。

## 参考リンク

- [SwiftSyntaxMacrosTestSupport](https://github.com/swiftlang/swift-syntax/tree/main/Sources/SwiftSyntaxMacrosTestSupport)
- [Point-Free: swift-macro-testing](https://github.com/pointfreeco/swift-macro-testing)
- [Point-Free: A new tool for testing macros in Swift](https://www.pointfree.co/blog/posts/114-a-new-tool-for-testing-macros-in-swift)
- [Point-Free: Episode #250 Testing & Debugging Macros](https://www.pointfree.co/episodes/ep250-testing-debugging-macros-part-1)

## 関連ドキュメント

- [診断とエラー](diagnostics.md) - エラー報告の実装
- [パッケージ構成](package-structure.md) - テストターゲットの設定
