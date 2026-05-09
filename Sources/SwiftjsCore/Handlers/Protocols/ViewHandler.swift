//
//  ViewHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import SwiftSyntax

public protocol ViewHandler {
    /// Translates a View.
    /// - Returns: A tuple containing:
    ///    - `output`: The generated JSX string (e.g. `<Button ... />` or `<VStack>`)
    ///    - `traverseChildren`: If true, the Visitor will walk the trailing closure as children.
    ///                          If false, the Visitor stops here (self-closing).
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool)
}
