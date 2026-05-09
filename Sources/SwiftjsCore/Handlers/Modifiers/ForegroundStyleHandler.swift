//
//  ForegroundStyleHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ForegroundStyleHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let color = firstArg.replacingOccurrences(of: "Color.", with: "")
                            .replacingOccurrences(of: ".", with: "")
        return [.style(key: "color", value: "\"\(color)\"")]
    }
}
