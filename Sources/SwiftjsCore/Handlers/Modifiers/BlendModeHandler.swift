//
//  BlendModeHandler.swift
//  swiftjs
//

import SwiftSyntax

struct BlendModeHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let mode = firstArg.replacingOccurrences(of: ".", with: "")
        return [.style(key: "mixBlendMode", value: "\"\(mode)\"")]
    }
}
