//
//  ScaleEffectHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ScaleEffectHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        return [.style(key: "transform", value: "\"scale(\(firstArg))\"")]
    }
}
