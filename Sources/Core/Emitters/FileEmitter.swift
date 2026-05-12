import Foundation

/// Emits a single Swift lowered file as TypeScript/JSX source
public final class FileEmitter {
    private let context = EmitterContext()
    private let exprEngine: ExpressionEmissionEngine
    private let viewEmitter: ViewEmitter
    private let statementEmitter: StatementEmitter
    
    public init() {
        self.exprEngine = ExpressionEmissionEngine()
        self.statementEmitter = StatementEmitter(exprEngine: exprEngine, context: context)
        self.viewEmitter = ViewEmitter(exprEngine: exprEngine, statementEmitter: statementEmitter)
    }
    
    public func emit(_ file: IRFile) -> String {
        var sections: [String] = []
        
        if file.components.contains(where: { !$0.stateVariables.isEmpty }) {
            sections.append("'use client';\nimport { useState } from 'react';")
        }
        
        // Imports
        for imp in file.imports {
            sections.append("import { \(imp.items.joined(separator: ", ")) } from '\(imp.module)';")
        }
        
        // Top-level statements
        if !file.statements.isEmpty {
            sections.append(file.statements.map(statementEmitter.emit).joined(separator: "\n"))
        }
        
        // Components
        for component in file.components {
            sections.append(emit(component))
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    public func emit(_ component: IRComponent) -> String {
        var result = ""
        if component.isDefaultExport {
            result += "export default function \(component.name)() {\n"
        } else {
            result += "export const \(component.name) = () => {\n"
        }
        context.indent()
        
        // State Hooks
        for stateVariable in component.stateVariables {
            let setterName = "set" + stateVariable.name.prefix(1).uppercased() + stateVariable.name.dropFirst()
            let initialValue = exprEngine.emit(stateVariable.initialValue)
            result += "\(context.linePrefix())const [\(stateVariable.name), \(setterName)] = useState(\(initialValue));\n"
        }
        
        // Component Body
        if let body = component.body {
            result += "\n\(context.linePrefix())return (\n"
            context.indent()
            result += "\(context.linePrefix())\(viewEmitter.emit(body))\n"
            context.outdent()
            result += "\(context.linePrefix()));\n"
        }
        
        context.outdent()
        result += "}\n"
        return result
    }
}
