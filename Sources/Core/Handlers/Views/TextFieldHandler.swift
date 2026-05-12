//
//  TextFieldHandler.swift
//  swiftjs
//

import SwiftSyntax

struct TextFieldHandler: ViewHandler {
    func handle(
        node: FunctionCallExprSyntax,
        props: [String],
        context: Transpiler
    ) -> (output: String, traverseChildren: Bool) {

        var properties: [IRProperty] = []

        for arg in node.arguments {
            let label = arg.label?.text
            let expr = arg.expression

            if label == nil || label == "title" {
                properties.append(IRProperty(name: "placeholder", value: IRHandlerBridge.shared.lowerExpression(expr)))
            }

            if label == "text" {
                let bindingName: String
                if let prefixOp = expr.as(PrefixOperatorExprSyntax.self),
                   prefixOp.operator.text == "$",
                   let declRef = prefixOp.expression.as(DeclReferenceExprSyntax.self) {
                    bindingName = declRef.baseName.text
                } else if let declRef = expr.as(DeclReferenceExprSyntax.self) {
                    let raw = declRef.baseName.text
                    bindingName = raw.hasPrefix("$") ? String(raw.dropFirst()) : raw
                } else {
                    bindingName = "text"
                }

                let capitalized = bindingName.prefix(1).uppercased() + bindingName.dropFirst()
                let bindingValue: IRExpression = .dictionary([
                    ("get", .identifier("() => \(bindingName)")),
                    ("set", .identifier("set\(capitalized)"))
                ])
                properties.append(IRProperty(name: "text", value: bindingValue))
            }
        }

        let view = IRHandlerBridge.shared.makeView(name: "TextField", properties: properties)
        return (IRHandlerBridge.shared.renderView(view, additionalAttributes: props), false)
    }
}