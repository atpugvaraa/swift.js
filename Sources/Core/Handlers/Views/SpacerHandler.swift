//
//  SpacerHandler.swift
//  swiftjs
//

import SwiftSyntax

struct SpacerHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let view = IRHandlerBridge.shared.makeView(name: "Spacer")
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
    }
}
