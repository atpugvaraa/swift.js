//
//  IgnoresSafeAreaHandler.swift
//  swiftjs
//

import SwiftSyntax

struct IgnoresSafeAreaHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        return [.prop(key: "data-ignores-safe-area", value: "\"true\"")]
    }
}
