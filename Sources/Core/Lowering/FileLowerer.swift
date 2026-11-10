import Foundation
import SwiftSyntax
import SwiftOperators

/// Top-level entry point for lowering entire Swift files to IR
public class FileLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer
    private let stmtLowerer: StatementLowerer
    private let modifierLowerer: ModifierLowerer
    private let viewLowerer: ViewLowerer
    
    public init() {
        self.context = LoweringContext()
        self.exprLowerer = ExpressionLowerer(context: context)
        self.stmtLowerer = StatementLowerer(context: context, exprLowerer: exprLowerer)
        self.modifierLowerer = ModifierLowerer(context: context, exprLowerer: exprLowerer)
        self.viewLowerer = ViewLowerer(context: context, exprLowerer: exprLowerer, modifierLowerer: modifierLowerer)
        // Wire up bidirectional dependency for closure body lowering
        self.exprLowerer.setStatementLowerer(stmtLowerer)
        self.exprLowerer.setViewLowerer(viewLowerer)
        self.viewLowerer.setStatementLowerer(stmtLowerer)
    }
    
    public func lower(_ parsed: SourceFileSyntax, fileName: String = "input.swift") -> IRFile {
        // Fold `a + b * c`, `x ? y : z` etc. into trees with Swift's real precedence. Unknown
        // (custom) operators stay unfolded and are reported during lowering.
        let sourceFileSyntax = OperatorTable.standardOperators
            .foldAll(parsed, errorHandler: { _ in }).as(SourceFileSyntax.self) ?? parsed
        context.fileName = fileName
        context.locationConverter = SourceLocationConverter(fileName: fileName, tree: sourceFileSyntax)

        // 1. Pre-pass: Semantic Analysis
        let analyzer = SemanticAnalyzer(componentRegistry: context.componentRegistry)
        analyzer.analyze(sourceFileSyntax)
        
        // Populate context with discovered symbols
        // (In a real implementation, context and analyzer would share the same symbol table instance)
        
        var imports: [IRImport] = []
        var components: [IRComponent] = []
        var models: [IRStatement] = []
        
        // 2. Lowering Phase
        for statement in sourceFileSyntax.statements {
            if let importStmt = statement.item.as(ImportDeclSyntax.self) {
                let irImport = lowerImport(importStmt)
                imports.append(irImport)
                context.addImport(irImport)
            }
        }
        
        // Model structs (non-View) first: Views may use them as types.
        context.modelTypes = Set(sourceFileSyntax.statements.compactMap { statement -> String? in
            guard let structDecl = statement.item.as(StructDeclSyntax.self),
                  !context.componentRegistry.isComponent(structDecl.name.text) else { return nil }
            return structDecl.name.text
        })

        // Props of every View in the file, so call sites can be checked before the View is lowered.
        for statement in sourceFileSyntax.statements {
            if let structDecl = statement.item.as(StructDeclSyntax.self),
               context.componentRegistry.isComponent(structDecl.name.text) {
                context.viewProps[structDecl.name.text] = structDecl.memberBlock.members.compactMap { member in
                    storedProp(member.decl).map { IRClosureParameter(name: $0.name, type: context.typeScriptType($0.type)) }
                }
            }
        }

        for statement in sourceFileSyntax.statements {
            if statement.item.is(ImportDeclSyntax.self) { continue }
            
            if let funcDecl = statement.item.as(FunctionDeclSyntax.self),
               let component = lowerFunctionAsComponent(funcDecl) {
                components.append(component)
            } else if let structDecl = statement.item.as(StructDeclSyntax.self),
                      let component = lowerStructAsComponent(structDecl) {
                components.append(component)
            } else if let structDecl = statement.item.as(StructDeclSyntax.self),
                      context.modelTypes.contains(structDecl.name.text) {
                if let model = lowerModel(structDecl) { models.append(model) }
            } else {
                // Only View structs (and component functions) are transpiled so far.
                context.addDiagnostic("not yet supported: top-level \(declarationName(statement.item))", at: statement)
            }
        }
        
        // 3. Post-process Imports: Replace generic 'SwiftUI' items with actual used components
        let used = Array(context.usedComponents).sorted()
        for i in 0..<imports.count {
            if imports[i].module == "@swiftuijs/ui" {
                imports[i] = IRImport(items: used, module: "@swiftuijs/ui")
            }
        }

        if !context.usedIcons.isEmpty {
            imports.append(IRImport(items: context.usedIcons.sorted(), module: "lucide-react"))
        }
        let file = IRFile(imports: imports, statements: models, components: components)
        
        // 3. Post-pass: IR Transformations
        let passContext = CompilerPassContext(
            diagnostics: analyzer.diagnostics,
            symbolTable: context.symbolTable,
            capabilityRegistry: context.capabilityRegistry,
            componentRegistry: context.componentRegistry
        )
        let pipeline = PassPipeline(context: passContext)
        pipeline.addPass(StateLoweringPass())
        // add other passes here...
        
        do {
            try pipeline.execute(on: file)
        } catch {
            context.addDiagnostic("Pass execution failed: \(error)")
        }
        for message in passContext.diagnostics.messages where message.severity == .error {
            context.addDiagnostic(message.message)
        }
        
        return file
    }
    
    private func lowerImport(_ importDecl: ImportDeclSyntax) -> IRImport {
        let moduleName = importDecl.path.compactMap { $0.name.text }.joined(separator: ".")
        
        let mappedModule: String
        if moduleName == "SwiftUI" {
            mappedModule = "@swiftuijs/ui"
        } else {
            mappedModule = moduleName
        }
        
        // Initial import, will be optimized in the post-process
        return IRImport(items: [], module: mappedModule)
    }
    
    private func lowerFunctionAsComponent(_ funcDecl: FunctionDeclSyntax) -> IRComponent? {
        let name = funcDecl.name.text
        
        // Check if registered as component
        guard context.componentRegistry.isComponent(name) else {
            return nil
        }
        
        let bodyNode = funcDecl.body.flatMap { lowerViewBody($0.statements) }
        
        return IRComponent(
            name: name,
            stateVariables: [],
            body: bodyNode,
            isDefaultExport: funcDecl.modifiers.contains { $0.name.text == "public" }
        )
    }
    
    private func lowerStructAsComponent(_ structDecl: StructDeclSyntax) -> IRComponent? {
        let name = structDecl.name.text
        
        // Structs conforming to View are registered in SemanticAnalyzer
        guard context.componentRegistry.isComponent(name) else {
            return nil
        }
        
        var bodyNode: IRViewNode? = nil
        var stateVariables: [IRStateVariable] = []
        var declarations: [IRStatement] = []
        // Methods may be called from anywhere in the struct, including before their declaration.
        context.viewMethods = Set(structDecl.memberBlock.members.compactMap {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text
        }.filter { $0 != "body" })
        // Function-typed props (`let onTap: () -> Void`) are callable too.
        context.viewMethods.formUnion((context.viewProps[name] ?? []).filter { $0.type == "() => void" }.map(\.name))
        
        for member in structDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self), funcDecl.name.text != "body" {
                if let method = lowerMethod(funcDecl) { declarations.append(method) }
                continue
            }
            if let computed = lowerComputedProperty(member.decl) {
                declarations.append(computed)
                continue
            }
            if let prop = storedProp(member.decl) {
                if context.typeScriptType(prop.type) == nil {
                    context.addDiagnostic("not yet supported: property \(prop.name): \(prop.type.trimmedDescription) in View \(name)", at: member)
                }
                continue
            }
            if !isSupportedViewMember(member.decl) {
                context.addDiagnostic(
                    "not yet supported: \(declarationName(member.decl)) in View \(name)", at: member)
                continue
            }
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                // Handle @State variables (simplified)
                if hasStateAttribute(varDecl.attributes) {
                    if let binding = varDecl.bindings.first,
                       let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       let initial = binding.initializer?.value {
                        let stateVar = IRStateVariable(
                            name: pattern.identifier.text,
                            initialValue: exprLowerer.lower(initial)
                        )
                        if let annotation = binding.typeAnnotation?.type {
                            stateVar.typeScriptType = context.typeScriptType(annotation)
                            if stateVar.typeScriptType == nil {
                                context.addDiagnostic(
                                    "not yet supported: @State type \(annotation.trimmedDescription)", at: annotation)
                            }
                        }
                        stateVariables.append(stateVar)
                        context.addStateVariable(stateVar)
                    }
                }
            }
            
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self), funcDecl.name.text == "body" {
                bodyNode = funcDecl.body.flatMap { lowerViewBody($0.statements) }
            }
            
            if let propDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in propDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       pattern.identifier.text == "body" {
                        // Handle var body: some View { ... }
                        // For now simplified to just check initializer if present
                        if let initializer = binding.initializer?.value {
                            bodyNode = viewLowerer.lowerViewExpression(initializer)
                        } else if let accessor = binding.accessorBlock {
                            switch accessor.accessors {
                            case .accessors(let list):
                                for acc in list {
                                    if acc.accessorSpecifier.text == "get", let block = acc.body {
                                        bodyNode = lowerViewBody(block.statements)
                                    }
                                }
                            case .getter(let block):
                                bodyNode = lowerViewBody(block)
                            }
                        }
                    }
                }
            }
        }
        return IRComponent(
            name: name,
            stateVariables: stateVariables,
            body: bodyNode,
            isDefaultExport: name == "Page" || structDecl.modifiers.contains { $0.name.text == "public" },
            declarations: declarations
        ).withProps(context.viewProps[name] ?? [])
    }
    
    /// Lowers a view body that is a single view expression. Several statements (an implicit
    /// TupleView, or code before the view) are reported rather than keeping only the last one.
    private func lowerViewBody(_ statements: CodeBlockItemListSyntax) -> IRViewNode? {
        guard statements.count == 1, let item = statements.first else {
            if statements.count > 1 {
                context.addDiagnostic("not yet supported: body with \(statements.count) statements", at: statements)
            }
            return nil
        }
        let expr = item.item.as(ExprSyntax.self) ?? item.item.as(ExpressionStmtSyntax.self)?.expression
        guard let expr, let view = viewLowerer.lowerViewExpression(expr) else {
            context.addDiagnostic("not yet supported: body \(item.item.kind)", at: item)
            return nil
        }
        return view
    }

    /// `var name: T { expr }` (or `{ return expr }`) -> `const name = expr;`, recomputed each
    /// render like SwiftUI. Returns nil for anything else, including `body`.
    private func lowerComputedProperty(_ decl: DeclSyntax) -> IRStatement? {
        guard let varDecl = decl.as(VariableDeclSyntax.self), varDecl.attributes.isEmpty,
              varDecl.bindings.count == 1, let binding = varDecl.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text, name != "body",
              case .getter(let items)? = binding.accessorBlock?.accessors, items.count == 1,
              let item = items.first else { return nil }
        let expr = item.item.as(ExprSyntax.self)
            ?? item.item.as(ExpressionStmtSyntax.self)?.expression
            ?? item.item.as(ReturnStmtSyntax.self)?.expression
        guard let expr else { return nil }
        return .variableDeclaration(name: name, isLet: true, value: exprLowerer.lower(expr))
    }

    /// `struct Todo { let id = UUID(); var title: String; var done = false }` -> type + initializer.
    private func lowerModel(_ structDecl: StructDeclSyntax) -> IRStatement? {
        let name = structDecl.name.text
        guard structDecl.genericParameterClause == nil else {
            context.addDiagnostic("not yet supported: generic struct \(name)", at: structDecl)
            return nil
        }
        var fields: [IRModelField] = []
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self), varDecl.bindings.count == 1,
                  let binding = varDecl.bindings.first, binding.accessorBlock == nil,
                  let fieldName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                context.addDiagnostic("not yet supported: \(declarationName(member.decl)) in struct \(name)", at: member)
                continue
            }
            let initial = binding.initializer?.value
            let type = binding.typeAnnotation.flatMap { context.typeScriptType($0.type) }
                ?? initial.flatMap(inferredType)
            guard let type else {
                context.addDiagnostic("not yet supported: property type of \(fieldName) in struct \(name)", at: binding)
                continue
            }
            let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)
            // `var x: T?` without a value implicitly defaults to nil (and is optional in the init)
            let implicitNil = !isLet && initial == nil && binding.typeAnnotation?.type.is(OptionalTypeSyntax.self) == true
            fields.append(IRModelField(
                name: fieldName, type: type,
                defaultValue: initial.map { exprLowerer.lower($0) } ?? (implicitNil ? .nilLiteral : nil),
                isParameter: !(isLet && initial != nil)))
        }
        return .model(name: name, fields: fields)
    }

    /// TypeScript type of a literal default value (`""`, `0`, `false`, `UUID()`).
    private func inferredType(_ expr: ExprSyntax) -> String? {
        if expr.is(StringLiteralExprSyntax.self) { return "string" }
        if expr.is(IntegerLiteralExprSyntax.self) || expr.is(FloatLiteralExprSyntax.self) { return "number" }
        if expr.is(BooleanLiteralExprSyntax.self) { return "boolean" }
        if expr.as(FunctionCallExprSyntax.self)?.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "UUID" {
            return "string"
        }
        return nil
    }

    /// `let name: T` / `var name: T` without initializer or wrapper: a value the caller passes in.
    private func storedProp(_ decl: DeclSyntax) -> (name: String, type: TypeSyntax)? {
        guard let varDecl = decl.as(VariableDeclSyntax.self), varDecl.attributes.isEmpty,
              varDecl.bindings.count == 1, let binding = varDecl.bindings.first,
              binding.initializer == nil, binding.accessorBlock == nil,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type else { return nil }
        return (name, type)
    }

    /// `func name(_ x: T) { … }` -> `const name = (x: T) => { … };`
    private func lowerMethod(_ funcDecl: FunctionDeclSyntax) -> IRStatement? {
        let signature = funcDecl.signature
        guard funcDecl.genericParameterClause == nil, signature.effectSpecifiers == nil,
              funcDecl.attributes.isEmpty, let body = funcDecl.body else {
            context.addDiagnostic("not yet supported: func \(funcDecl.name.text) (generic, async, throws or attributes)", at: funcDecl)
            return nil
        }
        var parameters: [IRClosureParameter] = []
        for param in signature.parameterClause.parameters {
            let name = (param.secondName ?? param.firstName).text
            guard param.defaultValue == nil, param.ellipsis == nil, let type = context.typeScriptType(param.type) else {
                context.addDiagnostic("not yet supported: parameter \(param.trimmedDescription)", at: param)
                return nil
            }
            parameters.append(IRClosureParameter(name: name, type: type))
        }
        let statements = body.statements.map { stmtLowerer.lowerCodeBlockItem($0) }
        return .functionDeclaration(name: funcDecl.name.text, parameters: parameters, body: statements)
    }

    /// View members the lowerer handles: `var body` and `@State var x = initial`.
    private func isSupportedViewMember(_ decl: DeclSyntax) -> Bool {
        if let funcDecl = decl.as(FunctionDeclSyntax.self) { return funcDecl.name.text == "body" }
        guard let varDecl = decl.as(VariableDeclSyntax.self),
              varDecl.bindings.count == 1, let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return false }
        if pattern.identifier.text == "body" { return true }
        return hasStateAttribute(varDecl.attributes) && binding.initializer != nil
    }

    /// Short human name for a declaration, e.g. `struct Todo`, `func addTodo`, `var remaining`.
    private func declarationName(_ node: some SyntaxProtocol) -> String {
        let syntax = Syntax(node)
        if let decl = syntax.as(StructDeclSyntax.self) { return "struct \(decl.name.text)" }
        if let decl = syntax.as(ClassDeclSyntax.self) { return "class \(decl.name.text)" }
        if let decl = syntax.as(EnumDeclSyntax.self) { return "enum \(decl.name.text)" }
        if let decl = syntax.as(ExtensionDeclSyntax.self) { return "extension \(decl.extendedType.trimmedDescription)" }
        if let decl = syntax.as(FunctionDeclSyntax.self) { return "func \(decl.name.text)" }
        if let decl = syntax.as(VariableDeclSyntax.self) {
            let names = decl.bindings.map { $0.pattern.trimmedDescription }.joined(separator: ", ")
            return "\(decl.bindingSpecifier.text) \(names)"
        }
        return "\(syntax.kind)"
    }

    private func hasStateAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attrSyntax = attribute.as(AttributeSyntax.self) else { continue }
            if let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                if ident.name.text == "State" { return true }
            }
        }
        return false
    }
    
    public func getDiagnostics() -> [DiagnosticMessage] {
        return context.diagnostics
    }
}
