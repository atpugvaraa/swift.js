//
//  FontWeightHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FontWeightHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let weight = firstArg.replacingOccurrences(of: ".", with: "")
        return [.style(key: "fontWeight", value: "\"\(weight)\"")]
    }
}
