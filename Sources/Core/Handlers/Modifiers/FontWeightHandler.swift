//
//  FontWeightHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FontWeightHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "fontWeight")
        let value: IRExpression
        if let firstArg = node.arguments.first?.expression {
            value = IRHandlerBridge.shared.lowerExpression(firstArg)
        } else {
            value = .stringLiteral("normal")
        }
        modifier.addEffect(.style(key: "fontWeight", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
