//
//  ButtonHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct ButtonHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {
        var title = IRExpression.stringLiteral("Button")
        var action = IRExpression.closure(IRClosureExpression(parameters: [], body: []))

        if let firstArgument = node.arguments.first {
            title = IRHandlerBridge.shared.lowerExpression(firstArgument.expression)
        }

        if let closure = node.trailingClosure {
            action = IRHandlerBridge.shared.lowerExpression(closure)
        }

        let view = IRHandlerBridge.shared.makeView(
            name: "Button",
            properties: [
                IRProperty(name: "title", value: title),
                IRProperty(name: "label", value: title),
                IRProperty(name: "action", value: action)
            ]
        )

        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
    }
}