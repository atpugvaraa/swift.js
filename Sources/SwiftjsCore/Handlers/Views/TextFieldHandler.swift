//
//  TextFieldHandler.swift
//  swiftjs
//

import SwiftSyntax
import Foundation

struct TextFieldHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        // Example: TextField("Placeholder", text: $name)
        
        var placeholder = ""
        var bindingVar = ""
        
        for arg in node.arguments {
            let label = arg.label?.text
            let expr = arg.expression.description
            
            if label == nil || label == "title" || label == "titleKey" {
                placeholder = expr
                if placeholder.hasPrefix("\"") && placeholder.hasSuffix("\"") {
                    placeholder = String(placeholder.dropFirst().dropLast())
                }
            } else if label == "text" {
                // Remove the '$' prefix from the state variable binding
                bindingVar = expr.replacingOccurrences(of: "$", with: "")
            }
        }
        
        var outputProps = props
        
        if !placeholder.isEmpty {
            outputProps.append("placeholder=\"\(placeholder)\"")
        }
        
        if !bindingVar.isEmpty {
            // Using standard React controlled component pattern
            outputProps.append("value={\(bindingVar)}")
            
            // Generate the onChange handler based on the state variable name
            let capitalized = bindingVar.prefix(1).uppercased() + bindingVar.dropFirst()
            outputProps.append("onChange={(e) => set\(capitalized)(e.target.value)}")
        }
        
        let allProps = outputProps.joined(separator: " ")
        let tag = "<TextField \(allProps) />\n"
        
        return (tag, false)
    }
}
