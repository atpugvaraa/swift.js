//
//  NavigationStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct NavigationStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let view = IRHandlerBridge.shared.makeView(name: "NavigationStack")
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), true)
    }
}
