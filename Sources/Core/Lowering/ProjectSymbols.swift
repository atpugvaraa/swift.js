import SwiftSyntax

/// Views and models declared across all files of the Swift module, and the TypeScript
/// module each file is emitted to, so files can use each other's declarations.
public struct ProjectSymbols {
    /// View name -> its props and module
    public var views: [String: (props: [IRClosureParameter], module: String)] = [:]
    /// Model struct name -> module
    public var models: [String: String] = [:]

    public init() {}

    /// Collects declarations from parsed files (`module` is where each file is emitted).
    public static func collect(_ files: [(syntax: SourceFileSyntax, module: String)]) -> ProjectSymbols {
        var symbols = ProjectSymbols()
        let structs = files.flatMap { file in
            file.syntax.statements.compactMap { $0.item.as(StructDeclSyntax.self) }.map { ($0, file.module) }
        }
        for (decl, module) in structs where !isView(decl) {
            symbols.models[decl.name.text] = module
        }
        // Prop types may mention models from any file
        let types = LoweringContext()
        types.modelTypes = Set(symbols.models.keys)
        for (decl, module) in structs where isView(decl) {
            let props = decl.memberBlock.members.compactMap { FileLowerer.storedProp($0.decl) }
                .map { IRClosureParameter(name: $0.name, type: types.typeScriptType($0.type)) }
            symbols.views[decl.name.text] = (props, module)
        }
        return symbols
    }

    /// `struct X: View`
    static func isView(_ decl: StructDeclSyntax) -> Bool {
        decl.inheritanceClause?.inheritedTypes.contains {
            $0.type.as(IdentifierTypeSyntax.self)?.name.text == "View"
        } ?? false
    }
}
