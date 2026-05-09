//
//  SpacerHandler.swift
//  swiftjs
//

import SwiftSyntax

struct SpacerHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<Spacer />\n" : "<Spacer \(allProps) />\n"
        return (tag, false)
    }
}
