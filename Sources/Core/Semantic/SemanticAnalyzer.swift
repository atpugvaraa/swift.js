//
//  SemanticAnalyzer.swift
//  swiftjs
//
//  Pre-pass that populates the symbol table from Swift AST
//

import Foundation
import SwiftSyntax

/// Pre-pass analyzer that populates the symbol table before lowering.
/// This enables the lowerer to make semantic decisions about identifiers.
public class SemanticAnalyzer {
    public let symbolTable: SymbolTable
    public let diagnostics: DiagnosticsCollector
    public let componentRegistry: ComponentRegistry
    
    public init(componentRegistry: ComponentRegistry = ComponentRegistry()) {
        self.symbolTable = SymbolTable()
        self.diagnostics = DiagnosticsCollector()
        self.componentRegistry = componentRegistry
    }
    
    /// Analyze a source file and populate the symbol table
    public func analyze(_ sourceFile: SourceFileSyntax) {
        for statement in sourceFile.statements {
            analyzeTopLevelItem(statement)
        }
    }
    
    // MARK: - Top-Level Analysis
    
    private func analyzeTopLevelItem(_ item: CodeBlockItemSyntax) {
        // Import declarations
        if let importDecl = item.item.as(ImportDeclSyntax.self) {
            analyzeImport(importDecl)
        }
        
        // Struct declarations (components)
        if let structDecl = item.item.as(StructDeclSyntax.self) {
            analyzeStruct(structDecl)
        }
        
        // Function declarations (function components)
        if let funcDecl = item.item.as(FunctionDeclSyntax.self) {
            analyzeFunction(funcDecl)
        }
        
        // Variable declarations
        if let varDecl = item.item.as(VariableDeclSyntax.self) {
            analyzeVariableDecl(varDecl, isTopLevel: true)
        }
    }
    
    // MARK: - Import Analysis
    
    private func analyzeImport(_ importDecl: ImportDeclSyntax) {
        let moduleName = importDecl.path.first?.name.text ?? "unknown"
        symbolTable.register(Symbol(
            name: moduleName,
            kind: .importedSymbol,
            type: .unknown
        ))
    }
    
    // MARK: - Struct Analysis
    
    private func analyzeStruct(_ structDecl: StructDeclSyntax) {
        let name = structDecl.name.text
        
        // Register as component if it conforms to View
        if conformsToView(structDecl) {
            symbolTable.registerComponent(name: name)
            componentRegistry.register(ComponentDefinition(name: name, kind: .customView))
        }
        
        symbolTable.pushScope(kind: .component, name: name)
        
        for member in structDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                analyzeVariableDecl(varDecl, isTopLevel: false)
            }
        }
        
        symbolTable.popScope()
    }
    
    private func conformsToView(_ structDecl: StructDeclSyntax) -> Bool {
        guard let inheritance = structDecl.inheritanceClause else { return false }
        for type in inheritance.inheritedTypes {
            if let ident = type.type.as(IdentifierTypeSyntax.self),
               ident.name.text == "View" {
                return true
            }
        }
        return false
    }
    
    // MARK: - Function Analysis
    
    private func analyzeFunction(_ funcDecl: FunctionDeclSyntax) {
        let name = funcDecl.name.text
        
        // If registered in component registry, treat as component
        if componentRegistry.isComponent(name) {
            symbolTable.registerComponent(name: name)
        }
        
        symbolTable.pushScope(kind: .function, name: name)
        
        // Register parameters
        if let params = funcDecl.signature.parameterClause.parameters as? FunctionParameterListSyntax {
            for param in params {
                let paramName = param.firstName.text
                let paramType: IRType = lowerTypeToIR(param.type)
                symbolTable.register(Symbol(
                    name: paramName,
                    kind: .parameter,
                    type: paramType
                ))
            }
        }
        
        symbolTable.popScope()
    }
    
    // MARK: - Variable Declaration Analysis
    
    private func analyzeVariableDecl(_ varDecl: VariableDeclSyntax, isTopLevel: Bool) {
        let isState = hasStateAttribute(varDecl.attributes)
        let isBinding = hasBindingAttribute(varDecl.attributes)
        let isMutable = varDecl.bindingSpecifier.text == "var"
        
        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return
        }
        
        let name = pattern.identifier.text
        
        // Skip 'body' — it's the view body, not a real variable
        if name == "body" { return }
        
        // Determine type
        let type: IRType
        if let typeAnnotation = binding.typeAnnotation?.type {
            type = lowerTypeToIR(typeAnnotation)
        } else if let initializer = binding.initializer?.value {
            type = inferTypeFromExpression(initializer)
        } else {
            type = .unknown
        }
        
        if isState {
            symbolTable.registerStateVariable(name: name, type: type)
        } else if isBinding {
            symbolTable.register(Symbol(name: name, kind: .localBinding, type: type, isState: false, isMutable: true))
        } else {
            symbolTable.registerLocalVariable(name: name, type: type, isMutable: isMutable)
        }
    }
    
    // MARK: - Type Lowering
    
    private func lowerTypeToIR(_ typeSyntax: TypeSyntax) -> IRType {
        if let ident = typeSyntax.as(IdentifierTypeSyntax.self) {
            let name = ident.name.text
            switch name {
            case "String": return .string
            case "Int": return .int
            case "Double", "CGFloat": return .double
            case "Bool": return .bool
            default: return .unknown
            }
        }
        if let optional = typeSyntax.as(OptionalTypeSyntax.self) {
            return .optional(lowerTypeToIR(optional.wrappedType))
        }
        if let array = typeSyntax.as(ArrayTypeSyntax.self) {
            return .array(lowerTypeToIR(array.element))
        }
        return .unknown
    }
    
    // MARK: - @State Detection
    
    private func hasStateAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attrSyntax = attribute.as(AttributeSyntax.self) else { continue }
            
            if let identifierType = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                if identifierType.name.text == "State" { return true }
            }
            
            if let memberType = attrSyntax.attributeName.as(MemberTypeSyntax.self) {
                if memberType.name.text == "State" { return true }
            }
        }
        return false
    }
    
    private func hasBindingAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attrSyntax = attribute.as(AttributeSyntax.self) else { continue }
            
            if let identifierType = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                if identifierType.name.text == "Binding" { return true }
            }
        }
        return false
    }
    
    // MARK: - Type Inference
    
    private func inferTypeFromExpression(_ expr: ExprSyntax) -> IRType {
        if expr.is(StringLiteralExprSyntax.self) { return .string }
        if expr.is(IntegerLiteralExprSyntax.self) { return .int }
        if expr.is(FloatLiteralExprSyntax.self) { return .double }
        if expr.is(BooleanLiteralExprSyntax.self) { return .bool }
        if expr.is(NilLiteralExprSyntax.self) { return .optional(.unknown) }
        if expr.is(ArrayExprSyntax.self) { return .array(.unknown) }
        return .unknown
    }
}
