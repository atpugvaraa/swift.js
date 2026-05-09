//
//  OnTapGestureHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OnTapGestureHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let trailingClosure = node.trailingClosure else { return [] }
        let statements = trailingClosure.statements.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return [.prop(key: "onClick", value: "() => { \(statements) }")]
    }
}
