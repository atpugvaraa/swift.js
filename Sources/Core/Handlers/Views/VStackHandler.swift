//
//  VStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct VStackHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {

        var properties: [IRProperty] = []

        for arg in node.arguments {
            let label = arg.label?.text
            let expr = arg.expression

            if label == "alignment" {
                let value: IRExpression
                if let member = expr.as(MemberAccessExprSyntax.self) {
                    value = .stringLiteral(member.declName.baseName.text)
                } else {
                    value = IRHandlerBridge.shared.lowerExpression(expr)
                }
                properties.append(IRProperty(name: "alignment", value: value))
            } else if label == "spacing" {
                properties.append(IRProperty(name: "spacing", value: IRHandlerBridge.shared.lowerExpression(expr)))
            }
        }

        let view = IRHandlerBridge.shared.makeView(name: "VStack", properties: properties)
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), true)
    }
}
