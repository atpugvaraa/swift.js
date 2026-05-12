//
//  PaddingHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct PaddingHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "padding")
        let value: IRExpression
        if let first = node.arguments.first?.expression {
            value = lowerPaddingValue(first)
        } else {
            value = .stringLiteral("1rem")
        }
        modifier.addEffect(.style(key: "padding", value: value))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }

    private func lowerPaddingValue(_ expr: ExprSyntax) -> IRExpression {
        if let intLit = expr.as(IntegerLiteralExprSyntax.self) {
            return .stringLiteral("\(intLit.literal.text)px")
        }
        if let floatLit = expr.as(FloatLiteralExprSyntax.self) {
            return .stringLiteral("\(floatLit.literal.text)px")
        }
        if let declRef = expr.as(DeclReferenceExprSyntax.self) {
            return .identifier(declRef.baseName.text)
        }
        if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
            return .stringLiteral(memberAccess.declName.baseName.text)
        }
        return IRHandlerBridge.shared.lowerExpression(expr)
    }
}
