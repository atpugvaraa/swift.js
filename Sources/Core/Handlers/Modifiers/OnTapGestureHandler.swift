//
//  OnTapGestureHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OnTapGestureHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "onTapGesture")
        let closureExpression: IRExpression

        if let trailingClosure = node.trailingClosure {
            closureExpression = IRHandlerBridge.shared.lowerExpression(trailingClosure)
        } else {
            closureExpression = .closure(IRClosureExpression(parameters: [], body: []))
        }

        modifier.addEffect(.interaction(event: "onClick", handler: closureExpression))
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
