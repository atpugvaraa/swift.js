//
//  AnimationHandler.swift
//  swiftjs
//

import SwiftSyntax

struct AnimationHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "animation")
        let animationExpression: IRExpression
        if let firstArg = node.arguments.first?.expression {
            animationExpression = IRHandlerBridge.shared.lowerExpression(firstArg)
        } else {
            animationExpression = .identifier("defaultAnimation")
        }
        modifier.addEffect(.animation(animationExpression))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
