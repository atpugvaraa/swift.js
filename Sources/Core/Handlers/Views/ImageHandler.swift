//
//  ImageHandler.swift
//  swiftjs
//

import SwiftSyntax

struct ImageHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {
        guard let firstArg = node.arguments.first?.expression else {
            let view = IRHandlerBridge.shared.makeView(name: "Image", properties: [IRProperty(name: "src", value: .stringLiteral(""))])
            return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
        }
        
        let srcValue: IRExpression
        if let stringLit = firstArg.as(StringLiteralExprSyntax.self) {
            let sourceString = stringLit.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if sourceString.hasPrefix("\"") && sourceString.hasSuffix("\"") {
                let innerString = String(sourceString.dropFirst().dropLast())
                srcValue = .stringLiteral(innerString.hasPrefix("http://") || innerString.hasPrefix("https://") ? innerString : "/\(innerString)")
            } else {
                srcValue = .stringLiteral(sourceString)
            }
        } else if let declRef = firstArg.as(DeclReferenceExprSyntax.self) {
            srcValue = .identifier(declRef.baseName.text)
        } else {
            srcValue = IRHandlerBridge.shared.lowerExpression(firstArg)
        }

        let view = IRHandlerBridge.shared.makeView(name: "Image", properties: [IRProperty(name: "src", value: srcValue)])
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
    }
}
