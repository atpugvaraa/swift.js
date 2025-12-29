//
//  Visitor.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import SwiftSyntax

class Visitor: SyntaxVisitor {
    unowned let transpiler: Transpiler
    
    init(transpiler: Transpiler) {
        self.transpiler = transpiler
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - 1. Handle Structs (Components)
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        
        // 🆕 FIX: Handle "Page" as Default Export for Next.js
        if name == "Page" {
            transpiler.output += "export default function Page() {\n"
        } else {
            transpiler.output += "export const \(name) = () => {\n"
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        let name = node.name.text
        if name == "Page" {
            transpiler.output += "}\n" // Close function
        } else {
            transpiler.output += "};\n" // Close const arrow func
        }
    }
    
    // MARK: - 2. Handle Variables (@State & Body)
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        
        // Debug: Uncomment this to see what attributes the visitor is actually seeing
        // print("Checking var: \(node.bindings.first?.pattern.description ?? "?") - Attrs: \(node.attributes.description)")

        // A. Handle @State
        // We check if ANY attribute's description contains "State" (handles @State, @SwiftUI.State, etc)
        let hasState = node.attributes.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.description.trimmingCharacters(in: .whitespaces) == "State"
        }

        if hasState {
            transpiler.isClientComponent = true
            
            if let binding = node.bindings.first,
               let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
               let value = binding.initializer?.value.description {
                
                transpiler.stateVariables.insert(name)
                
                let capitalized = name.prefix(1).uppercased() + name.dropFirst()
                transpiler.output += "  const [\(name), set\(capitalized)] = useState(\(value));\n"
            }
            return .skipChildren
        }
        
        // B. Handle 'body'
        // Swift: var body: some View { ... }
        if let binding = node.bindings.first,
           let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
           name == "body" {
            
            transpiler.output += "  return (\n"
            // We visit the children (the AccessorBlock) to output the content
            return .visitChildren
        }
        
        return .visitChildren
    }
    
    // Close the 'return (...)' block for body
    override func visitPost(_ node: VariableDeclSyntax) {
        if let binding = node.bindings.first,
           let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
           name == "body" {
            transpiler.output += "  );\n"
        }
    }
    
    // MARK: - 3. Handle Function Calls (Existing Logic)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text ??
                node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        else {
            return .visitChildren
        }
        
        // Modifiers (.padding)
        if name.first?.isLowercase == true {
            if let (baseView, modifiers) = unwindModifierChain(node: node) {
                processView(node: baseView, modifiers: modifiers)
                
                // Manually walk children (e.g. content of VStack)
                // Note: We need to traverse the arguments/closure of the base view
                if let trailingClosure = baseView.trailingClosure {
                    self.walk(trailingClosure)
                }
                
                if let baseName = baseView.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                   baseView.trailingClosure != nil {
                    transpiler.output += "</\(baseName)>\n"
                }
                return .skipChildren
            }
        }
        
        // CASE B: Base View (VStack, Text)
        if name.first?.isUppercase == true {
            
            // 🆕 FIX: Track the component usage!
            transpiler.usedComponents.insert(name)
            
            processView(node: node, modifiers: [])
            if node.trailingClosure != nil {
                return .visitChildren
            }
            return .skipChildren
        }
        
        return .visitChildren
    }
    
    override func visitPost(_ node: FunctionCallExprSyntax) {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else { return }
        if name.first?.isUppercase == true && node.trailingClosure != nil {
            transpiler.output += "</\(name)>\n"
        }
    }
    
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        for segment in node.segments {
            transpiler.output += segment.description
        }
        return .skipChildren
    }
    
    // MARK: - Helpers
    private func unwindModifierChain(node: FunctionCallExprSyntax) -> (FunctionCallExprSyntax, [FunctionCallExprSyntax])? {
        var chain = [FunctionCallExprSyntax]()
        var currentNode: FunctionCallExprSyntax? = node
        
        while let current = currentNode {
            chain.append(current)
            if let memberAccess = current.calledExpression.as(MemberAccessExprSyntax.self),
               let base = memberAccess.base?.as(FunctionCallExprSyntax.self) {
                
                if let baseName = base.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                   baseName.first?.isUppercase == true {
                    return (base, chain)
                }
                currentNode = base
            } else { return nil }
        }
        return nil
    }
    
    private func processView(node: FunctionCallExprSyntax, modifiers: [FunctionCallExprSyntax]) {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else { return }
        
        var styles: [String] = []
        var extraProps: [String] = []
        
        for mod in modifiers {
            if let modName = mod.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
               let handler = transpiler.modifierHandlers[modName] {
                
                if let result = handler.handle(node: mod, context: transpiler) {
                    switch result {
                    case .style(let key, let val): styles.append("\(key): \(val)")
                    case .prop(let key, let val): extraProps.append("\(key)={\(val)}")
                    }
                }
            }
        }
        
        if !styles.isEmpty {
            extraProps.append("style={{ \(styles.joined(separator: ", ")) }}")
        }
        
        let handler = transpiler.handlers[name] ?? transpiler.genericHandler
        transpiler.output += handler.handle(node: node, props: extraProps, context: transpiler)
    }
}
