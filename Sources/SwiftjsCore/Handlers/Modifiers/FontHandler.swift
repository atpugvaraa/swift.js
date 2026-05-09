//
//  FontHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FontHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        guard let firstArg = node.arguments.first?.expression.description else { return [] }
        let fontType = firstArg.replacingOccurrences(of: ".", with: "")
        
        let sizeMap: [String: String] = [
            "largeTitle": "2rem",
            "title": "1.5rem",
            "title2": "1.25rem",
            "title3": "1.125rem",
            "headline": "1rem",
            "subheadline": "0.875rem",
            "body": "1rem",
            "callout": "0.875rem",
            "footnote": "0.75rem",
            "caption": "0.75rem"
        ]
        
        let size = sizeMap[fontType] ?? "1rem"
        let weight = (fontType == "headline") ? "bold" : "normal"
        
        return [
            .style(key: "fontSize", value: "\"\(size)\""),
            .style(key: "fontWeight", value: "\"\(weight)\"")
        ]
    }
}
