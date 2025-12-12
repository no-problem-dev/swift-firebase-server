# Attached Macro（付与型マクロ）

`@MacroName` の形式で宣言に付与するマクロです。

## 概要

Attached Macroは特定の宣言に付与され、その宣言を拡張・変換します。[SE-0389](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md) で導入。

## マクロ役割一覧

| 役割 | 属性 | プロトコル | 生成対象 |
|------|------|-----------|----------|
| [Peer](#peer-macro) | `@attached(peer)` | `PeerMacro` | 同じスコープに宣言を追加 |
| [Member](#member-macro) | `@attached(member)` | `MemberMacro` | 型にメンバーを追加 |
| [MemberAttribute](#memberattribute-macro) | `@attached(memberAttribute)` | `MemberAttributeMacro` | メンバーに属性を追加 |
| [Accessor](#accessor-macro) | `@attached(accessor)` | `AccessorMacro` | プロパティにアクセサを追加 |
| [Extension](#extension-macro) | `@attached(extension)` | `ExtensionMacro` | extensionを生成 |
| [Body](#body-macro) | `@attached(body)` | `BodyMacro` | 関数本体を生成 |

---

## Peer Macro

宣言と同じスコープに新しい宣言を追加します。

### 宣言

```swift
@attached(peer, names: overloaded)
public macro AddCompletionHandler() = #externalMacro(
    module: "MyMacros",
    type: "AddCompletionHandlerMacro"
)
```

### プロトコル

```swift
public protocol PeerMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}
```

### 実装例

```swift
public struct AddCompletionHandlerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        // async関数からcompletion handler版を生成
        let completionHandlerFunc: DeclSyntax = """
            func \(funcDecl.name)(completion: @escaping (Result) -> Void) {
                Task {
                    let result = await \(funcDecl.name)()
                    completion(result)
                }
            }
            """
        return [completionHandlerFunc]
    }
}
```

### 使用例

```swift
@AddCompletionHandler
func fetchData() async -> Data { ... }

// 展開後（同じスコープに追加）:
// func fetchData(completion: @escaping (Result) -> Void) { ... }
```

---

## Member Macro

型定義にメンバー（プロパティ、メソッド、イニシャライザ等）を追加します。

### 宣言

```swift
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(
    module: "MyMacros",
    type: "MemberwiseInitMacro"
)
```

### プロトコル

```swift
public protocol MemberMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}
```

> **Note**: `conformingTo` パラメータは [SE-0407](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0407-member-macro-conformances.md) で追加。Extension Macroと連携してプロトコル適合情報を受け取れる。

### 実装例

```swift
public struct MemberwiseInitMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }

        // storedプロパティを抽出
        let properties = structDecl.memberBlock.members.compactMap { member -> (String, String)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let type = binding.typeAnnotation?.type.trimmedDescription
            else { return nil }
            return (name, type)
        }

        let params = properties.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
        let assignments = properties.map { "self.\($0.0) = \($0.0)" }.joined(separator: "\n")

        let initDecl: DeclSyntax = """
            init(\(raw: params)) {
                \(raw: assignments)
            }
            """
        return [initDecl]
    }
}
```

### 使用例

```swift
@MemberwiseInit
struct User {
    let name: String
    let age: Int
}

// 展開後:
// struct User {
//     let name: String
//     let age: Int
//     init(name: String, age: Int) {
//         self.name = name
//         self.age = age
//     }
// }
```

---

## MemberAttribute Macro

型のメンバーに属性を追加します。

### 宣言

```swift
@attached(memberAttribute)
public macro Observable() = #externalMacro(
    module: "MyMacros",
    type: "ObservableMacro"
)
```

### プロトコル

```swift
public protocol MemberAttributeMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax]
}
```

### 実装例

```swift
public struct ObservableMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // storedプロパティに@ObservationTrackedを追加
        guard member.is(VariableDeclSyntax.self) else {
            return []
        }

        return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: "ObservationTracked"))]
    }
}
```

### 使用例

```swift
@Observable
class Model {
    var name: String = ""
    var count: Int = 0
}

// 展開後（各プロパティに属性追加）:
// class Model {
//     @ObservationTracked var name: String = ""
//     @ObservationTracked var count: Int = 0
// }
```

---

## Accessor Macro

プロパティにアクセサ（getter/setter/willSet/didSet）を追加します。

### 宣言

```swift
@attached(accessor)
public macro Logged() = #externalMacro(
    module: "MyMacros",
    type: "LoggedMacro"
)
```

### プロトコル

```swift
public protocol AccessorMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax]
}
```

### 実装例

```swift
public struct LoggedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else {
            return []
        }

        return [
            AccessorDeclSyntax(accessorSpecifier: .keyword(.didSet)) {
                "print(\"\\(\(raw: name)) changed to \\(\(raw: name))\")"
            }
        ]
    }
}
```

### 使用例

```swift
struct Settings {
    @Logged var volume: Int = 50
}

// 展開後:
// struct Settings {
//     var volume: Int = 50 {
//         didSet {
//             print("\(volume) changed to \(volume)")
//         }
//     }
// }
```

---

## Extension Macro

型にextensionを追加します。[SE-0402](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0402-extension-macros.md) で導入。

### 宣言

```swift
@attached(extension, conformances: Equatable, Hashable, names: named(==), named(hash))
public macro AutoEquatable() = #externalMacro(
    module: "MyMacros",
    type: "AutoEquatableMacro"
)
```

### プロトコル

```swift
public protocol ExtensionMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax]
}
```

### 実装例

```swift
public struct AutoEquatableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): Equatable {
                static func == (lhs: \(type.trimmed), rhs: \(type.trimmed)) -> Bool {
                    // 実装
                }
            }
            """
        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [ext]
    }
}
```

### 使用例

```swift
@AutoEquatable
struct Point {
    var x: Int
    var y: Int
}

// 展開後（extension追加）:
// extension Point: Equatable {
//     static func == (lhs: Point, rhs: Point) -> Bool { ... }
// }
```

### conformancesパラメータ

`conformances:` で宣言したプロトコルのみ追加可能：

```swift
// Equatable, Hashableのみ追加可能
@attached(extension, conformances: Equatable, Hashable)
macro MyMacro() = ...

// 任意のプロトコルを追加しようとするとエラー
```

---

## Body Macro

関数の本体を生成・置換します。[SE-0415](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0415-function-body-macros.md) で導入。

### 宣言

```swift
@attached(body)
public macro Traced() = #externalMacro(
    module: "MyMacros",
    type: "TracedMacro"
)
```

### プロトコル

```swift
public protocol BodyMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax]
}
```

### 主な用途

1. **完全な合成**: メタデータから実装を生成（例：RPCスタブ）
2. **拡張**: 既存の本体をラップ（例：ロギング、トレース）
3. **置換**: 本体を別の実装に置換（例：クロージャへの移動）

### 使用例

```swift
@Traced
func processData() {
    // 実装
}

// 展開後（本体をラップ）:
// func processData() {
//     trace("processData started")
//     defer { trace("processData finished") }
//     // 元の実装
// }
```

---

## namesパラメータ

Attached Macroが名前を生成する場合、`names:` パラメータで宣言が必要：

| 指定 | 説明 | 例 |
|------|------|-----|
| `named(foo)` | 固定名 | `named(init)` |
| `prefixed(_)` | 接頭辞付き | `prefixed($)` |
| `suffixed(_)` | 接尾辞付き | `suffixed(Storage)` |
| `overloaded` | オーバーロード | 同名の宣言 |
| `arbitrary` | 任意の名前 | 動的に決定 |

```swift
// 固定名
@attached(member, names: named(init), named(description))
macro MyMacro() = ...

// 接頭辞付き（例：_storedName）
@attached(peer, names: prefixed(_))
macro Wrapper() = ...

// 複数指定
@attached(member, names: named(encode), named(decode), arbitrary)
macro Codable() = ...
```

---

## 複数の役割を持つマクロ

1つのマクロが複数の役割を持てます：

```swift
@attached(member, names: named(init))
@attached(extension, conformances: Codable)
@attached(memberAttribute)
public macro Model() = #externalMacro(
    module: "MyMacros",
    type: "ModelMacro"
)

// 実装は各プロトコルに準拠
public struct ModelMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    // 各プロトコルのexpansionメソッドを実装
}
```

## 関連ドキュメント

- [Freestanding Macro](freestanding-macros.md) - 独立型マクロ
- [パッケージ構成](package-structure.md) - マクロの登録方法
- [SwiftSyntax API](swiftsyntax-api.md) - 構文木の操作
