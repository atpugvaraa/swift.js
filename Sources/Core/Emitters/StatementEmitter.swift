import Foundation

/// Emits TypeScript statement blocks from IR statements
public final class StatementEmitter {
    private let exprEngine: ExpressionEmissionEngine
    private let context: EmitterContext
    
    public init(exprEngine: ExpressionEmissionEngine, context: EmitterContext) {
        self.exprEngine = exprEngine
        self.context = context
    }
    
    public func emit(_ statement: IRStatement) -> String {
        switch statement {
        case .expression(let expression):
            return "\(context.linePrefix())\(exprEngine.emit(expression));"
            
        case .variableDeclaration(let name, let isLet, let value):
            let keyword = isLet ? "const" : "let"
            return "\(context.linePrefix())\(keyword) \(name) = \(exprEngine.emit(value));"
            
        case .assignment(let variable, let value):
            return "\(context.linePrefix())\(variable) = \(exprEngine.emit(value));"
            
        case .augmentedAssignment(let variable, let op, let value):
            return "\(context.linePrefix())\(variable) \(op) \(exprEngine.emit(value));"
            
        case .ifStatement(let condition, let thenBranch, let elseBranch):
            return emitIfStatement(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
            
        case .guardStatement(let condition, let body):
            return emitGuardStatement(condition: condition, body: body)
            
        case .switchStatement(let value, let cases):
            return emitSwitchStatement(value: value, cases: cases)
            
        case .forLoop(let variable, let sequence, let body):
            return emitForLoop(variable: variable, sequence: sequence, body: body)
            
        case .whileLoop(let condition, let body):
            return emitWhileLoop(condition: condition, body: body)
            
        case .returnStatement(let value):
            if let value {
                return "\(context.linePrefix())return \(exprEngine.emit(value));"
            }
            return "\(context.linePrefix())return;"
            
        case .breakStatement:
            return "\(context.linePrefix())break;"
            
        case .continueStatement:
            return "\(context.linePrefix())continue;"
        }
    }
    
    // MARK: - If Statement
    
    private func emitIfStatement(condition: IRExpression, thenBranch: [IRStatement], elseBranch: [IRStatement]?) -> String {
        var result = "\(context.linePrefix())if (\(exprEngine.emit(condition))) {\n"
        context.indent()
        result += thenBranch.map(emit).joined(separator: "\n")
        context.outdent()
        result += "\n\(context.linePrefix())}"
        
        if let elseBranch {
            if elseBranch.count == 1, case .ifStatement(let nestedCond, let nestedThen, let nestedElse) = elseBranch[0] {
                result += " else if (\(exprEngine.emit(nestedCond))) {\n"
                context.indent()
                result += nestedThen.map(emit).joined(separator: "\n")
                context.outdent()
                result += "\n\(context.linePrefix())}"
                // Handle further else/else-if recursively or as a block
                if let nestedElse {
                    result += " else {\n"
                    context.indent()
                    result += nestedElse.map(emit).joined(separator: "\n")
                    context.outdent()
                    result += "\n\(context.linePrefix())}"
                }
            } else {
                result += " else {\n"
                context.indent()
                result += elseBranch.map(emit).joined(separator: "\n")
                context.outdent()
                result += "\n\(context.linePrefix())}"
            }
        }
        return result
    }
    
    // MARK: - Guard Statement
    
    private func emitGuardStatement(condition: IRExpression, body: [IRStatement]) -> String {
        var result = "\(context.linePrefix())if (!(\(exprEngine.emit(condition)))) {\n"
        context.indent()
        result += body.map(emit).joined(separator: "\n")
        context.outdent()
        result += "\n\(context.linePrefix())}"
        return result
    }
    
    // MARK: - Switch Statement
    
    private func emitSwitchStatement(value: IRExpression, cases: [IRSwitchCase]) -> String {
        var result = "\(context.linePrefix())switch (\(exprEngine.emit(value))) {\n"
        context.indent()
        for switchCase in cases {
            result += emitSwitchCase(switchCase)
            result += "\n"
        }
        context.outdent()
        result += "\(context.linePrefix())}"
        return result
    }
    
    private func emitSwitchCase(_ switchCase: IRSwitchCase) -> String {
        let label: String
        switch switchCase.pattern {
        case .expression(let expr):
            label = "\(context.linePrefix())case \(exprEngine.emit(expr)):"
        case .default:
            label = "\(context.linePrefix())default:"
        }
        
        var result = label + "\n"
        context.indent()
        result += switchCase.body.map(emit).joined(separator: "\n")
        result += "\n\(context.linePrefix())break;"
        context.outdent()
        return result
    }
    
    // MARK: - Loops
    
    private func emitForLoop(variable: String, sequence: IRExpression, body: [IRStatement]) -> String {
        var result = "\(context.linePrefix())for (const \(variable) of \(exprEngine.emit(sequence))) {\n"
        context.indent()
        result += body.map(emit).joined(separator: "\n")
        context.outdent()
        result += "\n\(context.linePrefix())}"
        return result
    }
    
    private func emitWhileLoop(condition: IRExpression, body: [IRStatement]) -> String {
        var result = "\(context.linePrefix())while (\(exprEngine.emit(condition))) {\n"
        context.indent()
        result += body.map(emit).joined(separator: "\n")
        context.outdent()
        result += "\n\(context.linePrefix())}"
        return result
    }
}
