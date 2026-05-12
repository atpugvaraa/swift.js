//
//  BlendModeHandler.swift
//  swiftjs
//

import SwiftSyntax

struct BlendModeHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "blendMode")
        let value: IRExpression
        if let firstArg = node.arguments.first?.expression {
            value = IRHandlerBridge.shared.lowerExpression(firstArg)
        } else {
            value = .stringLiteral("normal")
        }
        modifier.addEffect(.style(key: "mixBlendMode", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
