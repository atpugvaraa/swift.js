//
//  ButtonHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct ButtonHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        var buttonProps = ""
        var actionCode: String? = nil
        
        // 1. Parse Arguments (Keep existing logic)
        for argument in node.arguments {
            let label = argument.label?.text ?? "value"
            let value = argument.expression.description
            
            if label == "action" {
                actionCode = value
            } else if value.hasPrefix("\"") {
                 buttonProps += " label=\(value)"
            } else {
                 buttonProps += " \(label)={\(value)}"
            }
        }
        
        // 2. Handle Trailing Closure
        if actionCode == nil, let closure = node.trailingClosure {
            let statements = closure.statements.description
            actionCode = statements.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3. Process Action Code
        if let code = actionCode {
            var finalAction = ""
            var mutationFound = false
            
            for stateVar in context.stateVariables {
                let setter = "set" + stateVar.prefix(1).uppercased() + stateVar.dropFirst()
                
                // Case A: count += 1
                if code.contains(stateVar) && (code.contains("+=") || code.contains("-=")) {
                    if code.contains("+=") {
                        let parts = code.components(separatedBy: "+=")
                        if parts.count == 2 {
                             let val = parts[1].trimmingCharacters(in: .whitespaces)
                             finalAction = "{() => \(setter)(\(stateVar) + \(val))}"
                             mutationFound = true
                        }
                    }
             
                }
                // Case B: count = 5
                else if code.contains(stateVar) && code.contains("=") {
                     let parts = code.components(separatedBy: "=")
                     if parts.count >= 2 {
                         let val = parts[1].trimmingCharacters(in: .whitespaces)
                         finalAction = "{() => \(setter)(\(val))}"
                         mutationFound = true
                     }
                }
                // Case C: count + 1 (Implicit Setter - NEW for Closure)
                else if code.contains(stateVar) && (code.contains("+") || code.contains("-")) {
                     // Naive check: if code is just "count + 1", wrap it in setter
                     finalAction = "{() => \(setter)(\(code))}"
                     mutationFound = true
                }
            }
            
            if !mutationFound {
                // Fallback: Just execute the code
                // Fix: Remove extra braces so it acts as a direct arrow function body if simple
                if !code.contains("=>") {
                    // Use block { ... } to be safe for multiple lines,
                    // but for single lines this might return void.
                    // Ideally we'd analyze if it's a return statement, but for now:
                    finalAction = "{() => { \(code) }}"
                } else {
                    finalAction = "{\(code)}"
                }
            }
            buttonProps += " action=\(finalAction)"
        }
        
        let allProps = buttonProps + " " + props.joined(separator: " ")
        
        // Button handles its own content via 'label' or children.
        // If we found a closure and used it as action, we don't traverse.
        return ("<Button \(allProps) />\n", false)
    }
}
