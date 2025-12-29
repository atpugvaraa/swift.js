//
//  ViewHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import SwiftSyntax

/// A contract for any object that knows how to translate a specific Swift View into React code.
public protocol ViewHandler {
    /// Translates a FunctionCallExprSyntax (e.g., `VStack { }`) into a React string.
    /// - Parameters:
    ///   - node: The syntax node representing the function call.
    ///   - context: The main transpiler instance (to access shared state/config).
    /// - Returns: The generated JSX string (opening tag).
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> String
}
