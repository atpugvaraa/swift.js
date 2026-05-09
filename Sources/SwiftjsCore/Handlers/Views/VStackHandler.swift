//
//  VStackHandler.swift
//  swiftjs
//

import SwiftSyntax

struct VStackHandler: ViewHandler {
    func handle(node: FunctionCallExprSyntax, props: [String], context: Transpiler) -> (output: String, traverseChildren: Bool) {
        let allProps = props.joined(separator: " ")
        let tag = allProps.isEmpty ? "<VStack>\n" : "<VStack \(allProps)>\n"
        
        // We return traverseChildren: true so the Visitor walks the trailing closure (the contents of the VStack)
        return (tag, true)
    }
}
