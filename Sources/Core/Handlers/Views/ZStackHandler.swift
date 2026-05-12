//
//  ZStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ZStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let view = IRHandlerBridge.shared.makeView(name: "ZStack")
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), true)
    }
}
