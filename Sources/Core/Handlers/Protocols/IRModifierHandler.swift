//
//  IRModifierHandler.swift
//  swiftjs
//
//  New-generation modifier handler protocol that returns semantic effects instead of strings.
//  Legacy ModifierHandler protocol continues to work via IRHandlerBridge.
//

import SwiftSyntax

/// A modifier handler that produces semantic IR effects instead of raw string output.
/// This is the target protocol — all modifier handlers should eventually migrate to this.
public protocol IRModifierHandler {
    /// Lower a SwiftUI modifier call into semantic modifier effects.
    /// - Parameters:
    ///   - node: The SwiftSyntax function call representing the modifier
    ///   - context: The current lowering context for scope and diagnostics
    /// - Returns: A list of semantic modifier effects
    func lower(node: FunctionCallExprSyntax, context: LoweringContext) -> [IRModifierEffect]
}
