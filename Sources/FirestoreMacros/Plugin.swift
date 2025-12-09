import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FirestoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FirestoreSchemaMacro.self,
        CollectionMacro.self,
        SubCollectionMacro.self,
    ]
}
