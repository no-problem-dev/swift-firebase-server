import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StorageMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StorageSchemaMacro.self,
        FolderMacro.self,
        ObjectMacro.self,
    ]
}
