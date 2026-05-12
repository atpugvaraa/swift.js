//
//  IRViewHandler.swift
//  swiftjs
//
//  New-generation view handler protocol that returns IR instead of strings.
//  Legacy ViewHandler protocol continues to work via IRHandlerBridge.
//

import SwiftSyntax

/// A view handler that produces semantic IR instead of raw string output.
/// This is the target protocol — all view handlers should eventually migrate to this.
public protocol IRViewHandler {
    /// Lower a SwiftUI view call into semantic IR.
    /// - Parameters:
    ///   - node: The SwiftSyntax function call representing the view
    ///   - context: The current lowering context for scope and diagnostics
    /// - Returns: An IRViewNode if the handler can process this view, nil otherwise
    func lower(node: FunctionCallExprSyntax, context: LoweringContext) -> IRViewNode?
}
