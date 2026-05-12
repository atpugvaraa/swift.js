//
//  IgnoresSafeAreaHandler.swift
//  swiftjs
//

import SwiftSyntax

struct IgnoresSafeAreaHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        let modifier = IRModifier(name: "ignoresSafeArea")
        modifier.addEffect(.style(key: "data-ignores-safe-area", value: .boolLiteral(true)))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }
}
