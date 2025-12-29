//
//  ModifierHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import Foundation
import SwiftSyntax

public enum ModifierResult {
    case style(key: String, value: String) // e.g. padding: "10px"
    case prop(key: String, value: String)  // e.g. onClick: {...}
}

public protocol ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> ModifierResult?
}
