//
//  RotationEffectHandler.swift
//  swiftjs
//

import SwiftSyntax

struct RotationEffectHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "rotationEffect")
        let expression: IRExpression
        if let firstArgument = node.arguments.first?.expression {
            expression = IRHandlerBridge.shared.lowerExpression(firstArgument)
        } else {
            expression = .numberLiteral(0)
        }

        modifier.addEffect(.style(
            key: "transform",
            value: .functionCall(
                callee: IRExpression.identifier("rotate"),
                arguments: [IRArgument(label: nil, value: expression)]
            )
        ))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
