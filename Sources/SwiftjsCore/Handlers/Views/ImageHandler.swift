//
//  ImageHandler.swift
//  swiftjs
//

import SwiftSyntax
import Foundation

struct ImageHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        guard let firstArg = node.arguments.first?.expression.description else {
            return ("<Image src=\"\" />\n", false)
        }
        
        var srcValue = firstArg
        // For standard local images `Image("logo")`
        if srcValue.hasPrefix("\"") && srcValue.hasSuffix("\"") {
            let innerString = String(srcValue.dropFirst().dropLast())
            if innerString.hasPrefix("http://") || innerString.hasPrefix("https://") {
                srcValue = innerString // Keep URL as is
            } else {
                srcValue = "/\(innerString)" // Map to Next.js public folder
            }
        }
        
        let allProps = props.joined(separator: " ")
        let tag = "<Image src=\"\(srcValue)\" \(allProps) />\n"
        return (tag, false)
    }
}
