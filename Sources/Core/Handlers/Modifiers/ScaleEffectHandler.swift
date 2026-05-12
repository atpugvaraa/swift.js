//
//  ScaleEffectHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ScaleEffectHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "scaleEffect")
        let value: IRExpression
        if let firstArgument = node.arguments.first?.expression {
            value = IRHandlerBridge.shared.lowerExpression(firstArgument)
        } else {
            value = .numberLiteral(1)
        }

        modifier.addEffect(.style(
            key: "transform",
            value: .functionCall(
                callee: IRExpression.identifier("scale"),
                arguments: [IRArgument(label: nil, value: value)]
            )
        ))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
