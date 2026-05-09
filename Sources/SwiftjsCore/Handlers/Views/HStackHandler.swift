//
//  HStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct HStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<HStack>\n" : "<HStack \(allProps)>\n"
        return (tag, true)
    }
}
