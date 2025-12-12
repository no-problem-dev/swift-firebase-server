import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FirestoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // Schema macros
        FirestoreSchemaMacro.self,
        CollectionMacro.self,
        // Model macros
        FirestoreModelMacro.self,
        FieldMacro.self,
        FieldStrategyMacro.self,
        FieldIgnoreMacro.self,
    ]
}
