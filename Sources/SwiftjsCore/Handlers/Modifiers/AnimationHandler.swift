//
//  AnimationHandler.swift
//  swiftjs
//

import SwiftSyntax

struct AnimationHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let ease = firstArg.replacingOccurrences(of: ".", with: "")
        return [.prop(key: "transition", value: "{ ease: \"\(ease)\" }")]
    }
}
