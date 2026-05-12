//
//  BackgroundHandler.swift
//  swiftjs
//

import SwiftSyntax

struct BackgroundHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "background")
        let value: IRExpression

        if let firstArg = node.arguments.first?.expression {
            value = IRHandlerBridge.shared.lowerExpression(firstArg)
        } else {
            value = .stringLiteral("white")
        }

        modifier.addEffect(.style(key: "backgroundColor", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
