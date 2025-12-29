//
//  PaddingHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftSyntax

struct PaddingHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> ModifierResult? {
        // Case 1: .padding() -> Default 16px
        guard let firstArg = node.arguments.first?.expression else {
            return .style(key: "padding", value: "\"1rem\"")
        }
        
        // Case 2: .padding(20)
        return .style(key: "padding", value: "\"\(firstArg.description)px\"")
    }
}
