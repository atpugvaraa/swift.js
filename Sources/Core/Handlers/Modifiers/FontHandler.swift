//
//  FontHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FontHandler: ModifierHandler {
    func handle(
        node: FunctionCallExprSyntax,
        context: Transpiler
    ) -> [ModifierResult] {
        let modifier = IRModifier(name: "font")
        guard let firstArg = node.arguments.first?.expression else {
            modifier.addEffect(.style(key: "fontSize", value: .stringLiteral("1rem")))
            modifier.addEffect(.style(key: "fontWeight", value: .stringLiteral("normal")))
            return IRHandlerBridge.shared.renderModifierResults(modifier)
        }

        let fontType: String
        if let memberAccess = firstArg.as(MemberAccessExprSyntax.self), memberAccess.base == nil {
            fontType = memberAccess.declName.baseName.text
        } else if let funcCall = firstArg.as(FunctionCallExprSyntax.self),
                  let firstInner = funcCall.arguments.first?.expression.as(MemberAccessExprSyntax.self),
                  firstInner.base == nil {
            fontType = firstInner.declName.baseName.text
        } else {
            fontType = firstArg.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let (size, weight) = mapFontStyle(fontType)
        modifier.addEffect(.style(key: "fontSize", value: .stringLiteral(size)))
        modifier.addEffect(.style(key: "fontWeight", value: .stringLiteral(weight)))
        return IRHandlerBridge.shared.renderModifierResults(modifier)
    }

    private func mapFontStyle(_ fontType: String) -> (size: String, weight: String) {
        let sizeMap: [String: (size: String, weight: String)] = [
            "largeTitle": ("2rem", "normal"),
            "title": ("1.5rem", "normal"),
            "title2": ("1.25rem", "normal"),
            "title3": ("1.125rem", "normal"),
            "headline": ("1rem", "bold"),
            "subheadline": ("0.875rem", "bold"),
            "body": ("1rem", "normal"),
            "callout": ("0.875rem", "normal"),
            "footnote": ("0.75rem", "normal"),
            "caption": ("0.75rem", "normal"),
            "small": ("0.75rem", "normal"),
            "large": ("1.125rem", "normal")
        ]

        return sizeMap[fontType] ?? ("1rem", "normal")
    }
}
