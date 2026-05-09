//
//  ZStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ZStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<ZStack>\n" : "<ZStack \(allProps)>\n"
        return (tag, true)
    }
}
