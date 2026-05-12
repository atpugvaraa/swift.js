//
//  ForegroundStyleHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ForegroundStyleHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "foregroundStyle")
        let value: IRExpression
        if let firstArg = node.arguments.first?.expression {
            value = IRHandlerBridge.shared.lowerExpression(firstArg)
        } else {
            value = .stringLiteral("black")
        }
        modifier.addEffect(.style(key: "color", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
