//
//  OpacityHandler.swift
//  swiftjs
//

import SwiftSyntax

struct OpacityHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        return [.style(key: "opacity", value: firstArg)]
    }
}
