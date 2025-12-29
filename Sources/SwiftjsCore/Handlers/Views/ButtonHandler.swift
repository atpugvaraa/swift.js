//
//  ButtonHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct ButtonHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> String {
        var buttonProps = ""
        
        for argument in node.arguments {
            let label = argument.label?.text ?? "value"
            var value = argument.expression.description
            
            if label == "action" {
                let cleanValue = value.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").trimmingCharacters(in: .whitespaces)
                var mutationFound = false
                
                for stateVar in context.stateVariables {
                    let setter = "set" + stateVar.prefix(1).uppercased() + stateVar.dropFirst()
                    
                    // Case A: count += 1
                    if cleanValue.contains("\(stateVar) +=") {
                        let parts = cleanValue.components(separatedBy: "+=")
                        if parts.count == 2 {
                            let amount = parts[1].trimmingCharacters(in: .whitespaces)
                            value = "{() => \(setter)(\(stateVar) + \(amount))}"
                            mutationFound = true
                            break
                        }
                    }
                    // Case B: count = 10
                    else if cleanValue.contains("\(stateVar) =") {
                         let parts = cleanValue.components(separatedBy: "=")
                         if parts.count == 2 {
                             let newValue = parts[1].trimmingCharacters(in: .whitespaces)
                             value = "{() => \(setter)(\(newValue))}"
                             mutationFound = true
                             break
                         }
                    }
                    // Case C: Simple Expression "count + 1"
                    else if cleanValue.contains(stateVar) && cleanValue.contains("+") {
                         value = "{() => \(setter)(\(cleanValue))}"
                         mutationFound = true
                         break
                    }
                }
                
                if !mutationFound {
                    if !value.contains("=>") {
                        value = "{() => \(cleanValue)}"
                    } else {
                        value = "{\(cleanValue)}"
                    }
                }
                buttonProps += " action=\(value)"
            } else if value.hasPrefix("\"") {
                 buttonProps += " \(label)=\(value)"
            } else {
                 buttonProps += " \(label)={\(value)}"
            }
        }
        
        let allProps = buttonProps + " " + props.joined(separator: " ")
        return "<Button \(allProps) />\n"
    }
}
