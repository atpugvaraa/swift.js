//
//  TextHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax
import Foundation

struct TextHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> String {
        guard let firstArg = node.arguments.first?.expression else {
            return "<Text content=\"\" />\n"
        }
        
        var textContent = firstArg.description
        
        // --- FIX: Regex Replace \(...) -> ${...} ---
        if textContent.contains("\\(") {
            do {
                // Pattern: matches \( capture_group )
                let regex = try NSRegularExpression(pattern: "\\\\\\((.*?)\\)")
                let range = NSRange(location: 0, length: textContent.utf16.count)
                
                // Template: ${$1}
                textContent = regex.stringByReplacingMatches(in: textContent, options: [], range: range, withTemplate: "\\${$1}")
                
                // Wrap in backticks if it was a double-quoted string
                if textContent.hasPrefix("\"") && textContent.hasSuffix("\"") {
                    textContent = String(textContent.dropFirst().dropLast())
                    textContent = "{`\(textContent)`}"
                }
            } catch {
                print("Regex Error: \(error)")
            }
        }
        else if textContent.hasPrefix("\"") {
            // Standard String "Hello" - keep quotes
        } else {
            // Variable - wrap in braces
            textContent = "{\(textContent)}"
        }
        
        let allProps = props.joined(separator: " ")
        return "<Text content=\(textContent) \(allProps) />\n"
    }
}
