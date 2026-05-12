//
//  ScrollViewHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ScrollViewHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let view = IRHandlerBridge.shared.makeView(name: "ScrollView")
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), true)
    }
}
