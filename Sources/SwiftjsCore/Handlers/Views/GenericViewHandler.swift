//
//  GenericViewHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import SwiftSyntax

struct GenericViewHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> String {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else { return "" }
        
        var standardProps = ""
        
        for argument in node.arguments {
            let label = argument.label?.text ?? "value"
            var value = argument.expression.description
            
            // --- BINDING LOGIC ($var) ---
            if value.starts(with: "$") {
                let varName = String(value.dropFirst()) // remove $
                let capitalized = varName.prefix(1).uppercased() + varName.dropFirst()
                // Generate: value={{ get: () => count, set: setCount }}
                value = "{{ get: () => \(varName), set: set\(capitalized) }}"
            }
            // --- STANDARD LOGIC ---
            else if value.starts(with: ".") {
                value = "\"\(value.dropFirst())\""
            } else if argument.expression.is(StringLiteralExprSyntax.self) {
                // Keep quotes
            } else {
                value = "{\(value)}"
            }
            
            standardProps += " \(label)=\(value)"
        }
        
        let allProps = standardProps + " " + props.joined(separator: " ")
        
        if node.trailingClosure == nil {
            return "<\(name)\(allProps) />\n"
        } else {
            return "<\(name)\(allProps)>\n"
        }
    }
}
