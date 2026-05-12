//
//  GenericViewHandler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import SwiftSyntax

struct GenericViewHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else {
            return ("", false)
        }
        
        var properties: [IRProperty] = []
        
        for argument in node.arguments {
            let label = argument.label?.text ?? "value"
            let value = IRHandlerBridge.shared.lowerExpression(argument.expression)
            properties.append(IRProperty(name: label, value: value))
        }
        
        let view = IRHandlerBridge.shared.makeView(name: name, properties: properties)
        let output = IRHandlerBridge.shared.renderView(view, additionalAttributes: props)
        return (output, node.trailingClosure != nil)
    }
}
