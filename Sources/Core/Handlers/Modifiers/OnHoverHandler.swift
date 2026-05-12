//
//  OnHoverHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OnHoverHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "onHover")
        let hoverHandler: IRExpression
        if let trailingClosure = node.trailingClosure {
            hoverHandler = IRHandlerBridge.shared.lowerExpression(trailingClosure)
        } else {
            hoverHandler = .closure(IRClosureExpression(parameters: [], body: []))
        }

        modifier.addEffect(.interaction(event: "onMouseEnter", handler: hoverHandler))
        modifier.addEffect(.interaction(event: "onMouseLeave", handler: hoverHandler))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }

    // MARK: - Infix Assignment Expression Transpilation
    /// Handle assignment forms represented as InfixOperatorExprSyntax
    private func transpileInfixAssignmentExpression(_ infix: InfixOperatorExprSyntax) -> String {
        let operatorToken: String
        if let opRef = infix.operator.as(DeclReferenceExprSyntax.self) {
            operatorToken = opRef.baseName.text
        } else if infix.operator.is(AssignmentExprSyntax.self) {
            operatorToken = "="
        } else {
            return infix.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard operatorToken == "=" else {
            return infix.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let lhs = infix.leftOperand.as(DeclReferenceExprSyntax.self) else {
            return infix.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let variable = lhs.baseName.text
        let rhs = infix.rightOperand.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let setter = "set" + variable.prefix(1).uppercased() + variable.dropFirst()
        return "\(setter)(\(rhs))"
    }
}
