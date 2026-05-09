//
//  OnHoverHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OnHoverHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let trailingClosure = node.trailingClosure else { return [] }
        let statements = trailingClosure.statements.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            .prop(key: "onMouseEnter", value: "() => { \(statements) }"),
            .prop(key: "onMouseLeave", value: "() => { \(statements) }")
        ]
    }
}
