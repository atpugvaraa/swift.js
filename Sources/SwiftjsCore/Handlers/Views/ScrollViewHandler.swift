//
//  ScrollViewHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ScrollViewHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<ScrollView>\n" : "<ScrollView \(allProps)>\n"
        return (tag, true)
    }
}
