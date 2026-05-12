import Foundation
import SwiftSyntax

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
    
    public func lower(_ sourceFileSyntax: SourceFileSyntax) -> IRFile {
        // 1. Pre-pass: Semantic Analysis
        let analyzer = SemanticAnalyzer(componentRegistry: context.componentRegistry)
        analyzer.analyze(sourceFileSyntax)
        
        // Populate context with discovered symbols
        // (In a real implementation, context and analyzer would share the same symbol table instance)
        
        var imports: [IRImport] = []
        var components: [IRComponent] = []
        
        // 2. Lowering Phase
        for statement in sourceFileSyntax.statements {
            if let importStmt = statement.item.as(ImportDeclSyntax.self) {
                let irImport = lowerImport(importStmt)
                imports.append(irImport)
                context.addImport(irImport)
            }
        }
        
        for statement in sourceFileSyntax.statements {
            if statement.item.is(ImportDeclSyntax.self) { continue }
            
            if let funcDecl = statement.item.as(FunctionDeclSyntax.self) {
                if let component = lowerFunctionAsComponent(funcDecl) {
                    components.append(component)
                }
            } else if let structDecl = statement.item.as(StructDeclSyntax.self) {
                if let component = lowerStructAsComponent(structDecl) {
                    components.append(component)
                }
            }
        }
        
        // 3. Post-process Imports: Replace generic 'SwiftUI' items with actual used components
        let used = Array(context.usedComponents).sorted()
        for i in 0..<imports.count {
            if imports[i].module == "@swiftjs/runtime" {
                imports[i] = IRImport(items: used, module: "@swiftjs/runtime")
            }
        }

        let file = IRFile(imports: imports, statements: [], components: components)
        
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
        
        return file
    }
    
    private func lowerImport(_ importDecl: ImportDeclSyntax) -> IRImport {
        let moduleName = importDecl.path.compactMap { $0.name.text }.joined(separator: ".")
        
        let mappedModule: String
        if moduleName == "SwiftUI" {
            mappedModule = "@swiftjs/runtime"
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
        
        var bodyNode: IRViewNode? = nil
        if let body = funcDecl.body,
           let lastStatement = body.statements.last,
           let exprStmt = lastStatement.item.as(ExpressionStmtSyntax.self) {
            bodyNode = viewLowerer.lowerViewExpression(exprStmt.expression)
        }
        
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
        
        for member in structDecl.memberBlock.members {
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
                        stateVariables.append(stateVar)
                        context.addStateVariable(stateVar)
                    }
                }
            }
            
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self), funcDecl.name.text == "body" {
                if let body = funcDecl.body,
                   let lastStatement = body.statements.last,
                   let exprStmt = lastStatement.item.as(ExpressionStmtSyntax.self) {
                    bodyNode = viewLowerer.lowerViewExpression(exprStmt.expression)
                }
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
                                        if let lastStatement = block.statements.last {
                                            if let expr = lastStatement.item.as(ExprSyntax.self) {
                                                bodyNode = viewLowerer.lowerViewExpression(expr)
                                            } else if let exprStmt = lastStatement.item.as(ExpressionStmtSyntax.self) {
                                                bodyNode = viewLowerer.lowerViewExpression(exprStmt.expression)
                                            }
                                        }
                                    }
                                }
                            case .getter(let block):
                                if let lastStatement = block.last {
                                    if let expr = lastStatement.item.as(ExprSyntax.self) {
                                        bodyNode = viewLowerer.lowerViewExpression(expr)
                                    } else if let exprStmt = lastStatement.item.as(ExpressionStmtSyntax.self) {
                                        bodyNode = viewLowerer.lowerViewExpression(exprStmt.expression)
                                    }
                                }
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
            isDefaultExport: name == "Page" || structDecl.modifiers.contains { $0.name.text == "public" }
        )
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
    
    public func getDiagnostics() -> [String] {
        return context.diagnostics
    }
}
