//
//  OpacityHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OpacityHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "opacity")
        let value = node.arguments.first.map { IRHandlerBridge.shared.lowerExpression($0.expression) } ?? .numberLiteral(1)
        modifier.addEffect(.style(key: "opacity", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
