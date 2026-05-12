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
        
        // FIX: Handle "Page" as Default Export for Next.js
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
        
        // A. Handle @State - Use semantic attribute inspection, not string parsing
        if hasStateAttribute(node.attributes) {
            transpiler.isClientComponent = true
            
            if let binding = node.bindings.first,
               let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
               let initExpr = binding.initializer?.value {
                
                transpiler.stateVariables.insert(name)
                               // Transpile initializer value with proper quoting for strings
                               let value = transpileStateInitializerValue(initExpr)
               
                
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
    
    // MARK: - Semantic @State Attribute Detection
    /// Check if variable has @State attribute using AST inspection, not string parsing
    private func hasStateAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attrSyntax = attribute.as(AttributeSyntax.self) else { continue }
            
            // Case 1: Identifier type syntax (common in newer SwiftSyntax)
            if let identifierType = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                if identifierType.name.text == "State" {
                    return true
                }
            }
            
            // Case 2: Qualified @SwiftUI.State or similar
            if let memberType = attrSyntax.attributeName.as(MemberTypeSyntax.self) {
                if memberType.name.text == "State" {
                    return true
                }
            }

            // Case 3: Fallback textual check for syntax variants
            let attrName = attrSyntax.attributeName.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if attrName == "State" || attrName.hasSuffix(".State") {
                return true
            }
        }
        
        return false
    }

    // MARK: - State Initializer Value Transpilation
    /// Transpile @State initializer value using AST inspection
    private func transpileStateInitializerValue(_ expr: ExprSyntax) -> String {
        // Case 1: String literal - keep quoted for JS/TS
        if let stringLit = expr.as(StringLiteralExprSyntax.self) {
            var content = ""
            for segment in stringLit.segments {
                content += segment.description
            }
            return "\"\(content)\""
        }

        // Case 2: Numeric literals
        if let intLit = expr.as(IntegerLiteralExprSyntax.self) {
            return intLit.literal.text
        }

        if let floatLit = expr.as(FloatLiteralExprSyntax.self) {
            return floatLit.literal.text
        }

        // Case 3: Boolean literal
        if let boolLit = expr.as(BooleanLiteralExprSyntax.self) {
            return boolLit.literal.text
        }

        // Case 4: Nil literal
        if expr.is(NilLiteralExprSyntax.self) {
            return "null"
        }

        // Fallback: preserve expression source as-is
        return expr.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Close the 'return (...)' block for body
    override func visitPost(_ node: VariableDeclSyntax) {
        if let binding = node.bindings.first,
           let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
           name == "body" {
            transpiler.output += "  );\n"
        }
    }
    
    // MARK: - 3. Handle Function Calls
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text ??
                node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        else {
            return .visitChildren
        }
        
        // CASE A: Modifier (lowercase)
        if name.first?.isLowercase == true {
            if let (baseView, modifiers) = unwindModifierChain(node: node) {
                // Track usage
                if let baseName = baseView.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text {
                    transpiler.usedComponents.insert(baseName)
                }
                processView(node: baseView, modifiers: modifiers)
                return .skipChildren
            }
        }
        
        // CASE B: Base View (Uppercase)
        if name.first?.isUppercase == true {
            transpiler.usedComponents.insert(name)
            processView(node: node, modifiers: [])
            return .skipChildren
        }
        
        return .visitChildren
    }
    
    //    override func visitPost(_ node: FunctionCallExprSyntax) {
    //        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else { return }
    //        if name.first?.isUppercase == true && node.trailingClosure != nil {
    //            transpiler.output += "</\(name)>\n"
    //        }
    //    }
    
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
        
        // 1. Process Modifiers (Styles & Props)
        var stylesDict: [String: String] = [:]
        var extraProps: [String] = []
        
        // Iterate modifiers in reverse (from inside out) 
        // so that outer modifiers (which were at the start of the chain) 
        // are processed LAST and override inner ones in the dictionary.
        for mod in modifiers.reversed() {
            if let modName = mod.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
               !modName.isEmpty {
                transpiler.usedModifiers.insert(modName)

                if let handler = transpiler.modifierHandlers[modName] {
                    let results = handler.handle(node: mod, context: transpiler)
                    for result in results {
                        switch result {
                        case .style(let key, let val):
                            stylesDict[key] = val
                        case .prop(let key, let val):
                            extraProps.append("\(key)={\(val)}")
                        }
                    }
                }
            }
        }
        
        if !stylesDict.isEmpty {
            let styleEntries = stylesDict.map { "\($0.key): \($0.value)" }.sorted().joined(separator: ", ")
            extraProps.append("style={{ \(styleEntries) }}")
        }
        
        // 2. Delegate to Handler
        let handler = transpiler.handlers[name] ?? transpiler.genericHandler
        let (output, traverseChildren) = handler.handle(node: node, props: extraProps, context: transpiler)
        
        transpiler.output += output
        
        // 3. Handle Children based on Handler decision
        if traverseChildren && node.trailingClosure != nil {
            self.walk(node.trailingClosure!)
        }
        
        // 4. Close Tag (If we traversed children)
        if traverseChildren && node.trailingClosure != nil {
            transpiler.output += "</\(name)>\n"
        }
    }
}
