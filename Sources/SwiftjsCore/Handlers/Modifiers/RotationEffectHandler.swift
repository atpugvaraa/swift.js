//
//  RotationEffectHandler.swift
//  swiftjs
//

import SwiftSyntax

struct RotationEffectHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let angle = firstArg.replacingOccurrences(of: ".degrees(", with: "")
                            .replacingOccurrences(of: ")", with: "")
        
        return [.style(key: "transform", value: "\"rotate(\(angle)deg)\"")]
    }
}
