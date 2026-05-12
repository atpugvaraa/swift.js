//
//  FrameHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FrameHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "frame")

        for arg in node.arguments {
            guard let label = arg.label?.text else { continue }

            let value = lowerDimensionValue(arg.expression)
            switch label {
            case "width":
                modifier.addEffect(.frame(width: value, height: nil))
            case "height":
                modifier.addEffect(.frame(width: nil, height: value))
            case "maxWidth":
                modifier.addEffect(.style(key: "maxWidth", value: value))
            case "maxHeight":
                modifier.addEffect(.style(key: "maxHeight", value: value))
            default:
                break
            }
        }
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
    
    private func lowerDimensionValue(_ expr: ExprSyntax) -> IRExpression {
        if let memberAccess = expr.as(MemberAccessExprSyntax.self),
           memberAccess.base == nil,
           memberAccess.declName.baseName.text == "infinity" {
            return .stringLiteral("100%")
        }

        if let intLit = expr.as(IntegerLiteralExprSyntax.self) {
            return .stringLiteral("\(intLit.literal.text)px")
        }

        if let floatLit = expr.as(FloatLiteralExprSyntax.self) {
            return .stringLiteral("\(floatLit.literal.text)px")
        }

        if let declRef = expr.as(DeclReferenceExprSyntax.self) {
            return .identifier(declRef.baseName.text)
        }

        return IRHandlerBridge.shared.lowerExpression(expr)
    }
}
