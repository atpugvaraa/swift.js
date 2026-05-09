//
//  FrameHandler.swift
//  swiftjs
//

import SwiftSyntax

struct FrameHandler: ModifierHandler {
    func handle(node: FunctionCallExprSyntax, context: Transpiler) -> [ModifierResult] {
        var results: [ModifierResult] = []
        
        for arg in node.arguments {
            let label = arg.label?.text
            let expr = arg.expression.description
            
            if label == "width" || label == nil {
                if expr == ".infinity" {
                    results.append(.style(key: "width", value: "\"100%\""))
                } else {
                    results.append(.style(key: "width", value: "\"\(expr)px\""))
                }
            } else if label == "height" {
                if expr == ".infinity" {
                    results.append(.style(key: "height", value: "\"100%\""))
                } else {
                    results.append(.style(key: "height", value: "\"\(expr)px\""))
                }
            } else if label == "maxWidth" {
                if expr == ".infinity" {
                    results.append(.style(key: "width", value: "\"100%\""))
                } else {
                    results.append(.style(key: "maxWidth", value: "\"\(expr)px\""))
                }
            } else if label == "maxHeight" {
                if expr == ".infinity" {
                    results.append(.style(key: "height", value: "\"100%\""))
                } else {
                    results.append(.style(key: "maxHeight", value: "\"\(expr)px\""))
                }
            }
        }
        
        return results
    }
}
