import Foundation

/// Identifies @State variables and ensures they are correctly represented for React emission.
/// Specifically, it transforms assignments to state variables into React setter calls.
public class StateLoweringPass: CompilerPass {
    public let name = "StateLowering"
    
    public func run(on program: IRFile, context: CompilerPassContext) throws {
        for component in program.components {
            lowerState(in: component)
        }
    }
    
    private func lowerState(in component: IRComponent) {
        let stateVarNames = Set(component.stateVariables.map { $0.name })
        if stateVarNames.isEmpty { return }
        
        if let body = component.body {
            lowerStateInView(body, stateVars: stateVarNames)
        }
    }
    
    private func lowerStateInView(_ node: IRViewNode, stateVars: Set<String>) {
        // 1. Lower state in statements (e.g., Button actions)
        for i in 0..<node.statements.count {
            node.statements[i] = lowerStateInStatement(node.statements[i], stateVars: stateVars)
        }
        
        // 2. Lower state in modifiers (e.g., onTapGesture)
        for modifier in node.modifiers {
            for i in 0..<modifier.effects.count {
                modifier.effects[i] = lowerStateInEffect(modifier.effects[i], stateVars: stateVars)
            }
        }
        
        // 3. Lower state in children
        for child in node.children {
            lowerStateInView(child, stateVars: stateVars)
        }
    }
    
    private func lowerStateInStatement(_ stmt: IRStatement, stateVars: Set<String>) -> IRStatement {
        switch stmt {
        case .expression(let expr):
            return .expression(lowerStateInExpression(expr, stateVars: stateVars))
        case .variableDeclaration(let name, let isLet, let value):
            return .variableDeclaration(name: name, isLet: isLet, value: lowerStateInExpression(value, stateVars: stateVars))
        case .ifStatement(let condition, let thenBranch, let elseBranch):
            return .ifStatement(
                condition: lowerStateInExpression(condition, stateVars: stateVars),
                thenBranch: thenBranch.map { lowerStateInStatement($0, stateVars: stateVars) },
                elseBranch: elseBranch?.map { lowerStateInStatement($0, stateVars: stateVars) }
            )
        case .forLoop(let variable, let sequence, let body):
            return .forLoop(
                variable: variable,
                sequence: lowerStateInExpression(sequence, stateVars: stateVars),
                body: body.map { lowerStateInStatement($0, stateVars: stateVars) }
            )
        default:
            return stmt
        }
    }
    
    private func lowerStateInExpression(_ expr: IRExpression, stateVars: Set<String>) -> IRExpression {
        switch expr {
        case .assignment(let target, let value):
            if case .identifier(let name) = target, stateVars.contains(name) {
                let setterName = "set" + name.prefix(1).uppercased() + name.dropFirst()
                return .functionCall(callee: .identifier(setterName), arguments: [IRArgument(value: lowerStateInExpression(value, stateVars: stateVars))])
            }
            return .assignment(target: target, value: lowerStateInExpression(value, stateVars: stateVars))
            
        case .augmentedAssignment(let target, let op, let value):
            if case .identifier(let name) = target, stateVars.contains(name) {
                let setterName = "set" + name.prefix(1).uppercased() + name.dropFirst()
                let binaryOp = mapAugmentedToBinary(op)
                let newValue = IRExpression.binary(lhs: .identifier(name), op: binaryOp, rhs: lowerStateInExpression(value, stateVars: stateVars))
                return .functionCall(callee: .identifier(setterName), arguments: [IRArgument(value: newValue)])
            }
            return .augmentedAssignment(target: target, op: op, value: lowerStateInExpression(value, stateVars: stateVars))
            
        case .binary(let lhs, let op, let rhs):
            return .binary(lhs: lowerStateInExpression(lhs, stateVars: stateVars), op: op, rhs: lowerStateInExpression(rhs, stateVars: stateVars))
            
        case .unary(let op, let inner):
            return .unary(op: op, expr: lowerStateInExpression(inner, stateVars: stateVars))
            
        case .functionCall(let callee, let args):
            let loweredArgs = args.map { IRArgument(label: $0.label, value: lowerStateInExpression($0.value, stateVars: stateVars)) }
            return .functionCall(callee: lowerStateInExpression(callee, stateVars: stateVars), arguments: loweredArgs)
            
        case .closure(let closure):
            let loweredBody = closure.body.map { lowerStateInStatement($0, stateVars: stateVars) }
            return .closure(IRClosureExpression(parameters: closure.parameters, body: loweredBody))
            
        case .interpolatedString(let parts):
            let loweredParts = parts.map { part -> IRInterpolatedPart in
                if case .expression(let e) = part {
                    return .expression(lowerStateInExpression(e, stateVars: stateVars))
                }
                return part
            }
            return .interpolatedString(loweredParts)
            
        case .view(let viewNode):
            lowerStateInView(viewNode, stateVars: stateVars)
            return .view(viewNode)
            
        default:
            return expr
        }
    }
    
    private func lowerStateInEffect(_ effect: IRModifierEffect, stateVars: Set<String>) -> IRModifierEffect {
        switch effect {
        case .interaction(let event, let handler):
            return .interaction(event: event, handler: lowerStateInExpression(handler, stateVars: stateVars))
        default:
            return effect
        }
    }
    
    private func mapAugmentedToBinary(_ op: IRAugmentedAssignmentOperator) -> IRBinaryOperator {
        switch op {
        case .addAssign: return .add
        case .subtractAssign: return .subtract
        case .multiplyAssign: return .multiply
        case .divideAssign: return .divide
        case .moduloAssign: return .modulo
        }
    }
}

