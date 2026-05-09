//
//  NavigationStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct NavigationStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<NavigationStack>\n" : "<NavigationStack \(allProps)>\n"
        return (tag, true)
    }
}
