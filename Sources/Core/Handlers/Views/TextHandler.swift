//
//  TextHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct TextHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {
        guard let firstArg = node.arguments.first?.expression else {
            let emptyView = IRHandlerBridge.shared.makeView(
                name: "Text",
                properties: [IRProperty(name: "content", value: .stringLiteral(""))]
            )
            return (IRHandlerBridge.shared.renderView(emptyView, additionalAttributes: props), false)
        }
        
        let content = IRHandlerBridge.shared.lowerExpression(firstArg)
        let view = IRHandlerBridge.shared.makeView(
            name: "Text",
            properties: [IRProperty(name: "content", value: content)]
        )
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
    }
}
