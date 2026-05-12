import Foundation

/// Validates IR for basic semantic correctness before emission
public final class SemanticValidator {
    public struct Issue: Identifiable {
        public enum Kind: String {
            case error
            case warning
        }
        
        public let id = UUID()
        public let kind: Kind
        public let message: String
        public let sourceLocation: SourceLocation?
        
        public init(kind: Kind, message: String, sourceLocation: SourceLocation? = nil) {
            self.kind = kind
            self.message = message
            self.sourceLocation = sourceLocation
        }
    }
    
    public init() {}
    
    public func validate(_ program: IRProgram) -> [Issue] {
        var issues: [Issue] = []
        
        if program.files.isEmpty {
            issues.append(Issue(kind: .warning, message: "Program contains no files"))
        }
        
        for file in program.files {
            issues.append(contentsOf: validate(file))
        }
        
        return issues
    }
    
    public func validate(_ file: IRFile) -> [Issue] {
        var issues: [Issue] = []
        
        for component in file.components {
            if component.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(Issue(kind: .error, message: "Component name cannot be empty", sourceLocation: component.sourceLocation))
            }
            
            if let body = component.body {
                issues.append(contentsOf: validate(body))
            }
        }
        
        for statement in file.statements {
            issues.append(contentsOf: validate(statement))
        }
        
        return issues
    }
    
    public func validate(_ view: IRViewNode) -> [Issue] {
        var issues: [Issue] = []
        
        if view.componentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(Issue(kind: .error, message: "View component name cannot be empty", sourceLocation: view.sourceLocation))
        }
        
        for child in view.children {
            issues.append(contentsOf: validate(child))
        }
        
        for statement in view.statements {
            issues.append(contentsOf: validate(statement))
        }
        
        return issues
    }
    
    public func validate(_ statement: IRStatement) -> [Issue] {
        switch statement {
        case .expression(let expression):
            return validate(expression)
        case .variableDeclaration(_, _, let value):
            return validate(value)
        case .assignment:
            return []
        case .augmentedAssignment:
            return []
        case .ifStatement(_, let thenBranch, let elseBranch):
            return thenBranch.flatMap(validate) + (elseBranch ?? []).flatMap(validate)
        case .guardStatement(_, let body):
            return body.flatMap(validate)
        case .switchStatement(_, let cases):
            return cases.flatMap { validate($0) }
        case .forLoop(_, let sequence, let body):
            return validate(sequence) + body.flatMap(validate)
        case .whileLoop(let condition, let body):
            return validate(condition) + body.flatMap(validate)
        case .returnStatement(let value):
            return value.map(validate) ?? []
        case .breakStatement, .continueStatement:
            return []
        }
    }
    
    public func validate(_ switchCase: IRSwitchCase) -> [Issue] {
        switchCase.body.flatMap(validate)
    }
    
    public func validate(_ expression: IRExpression) -> [Issue] {
        switch expression {
        case .identifier(let name):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return [Issue(kind: .warning, message: "Identifier expression is empty")]
            }
            return []
        case .stringLiteral, .numberLiteral, .boolLiteral, .nilLiteral, .self:
            return []
        case .array(let elements):
            return elements.flatMap(validate)
        case .dictionary(let pairs):
            return pairs.flatMap { validate($0.1) }
        case .tuple(let elements):
            return elements.flatMap(validate)
        case .binary(let lhs, _, let rhs):
            return validate(lhs) + validate(rhs)
        case .unary(_, let expr):
            return validate(expr)
        case .ternary(let condition, let thenExpr, let elseExpr):
            return validate(condition) + validate(thenExpr) + validate(elseExpr)
        case .assignment(let target, let value):
            return validate(target) + validate(value)
        case .augmentedAssignment(let target, _, let value):
            return validate(target) + validate(value)
        case .interpolatedString(let parts):
            return parts.flatMap { part in
                switch part {
                case .literal:
                    return [Issue]()
                case .expression(let expr):
                    return validate(expr)
                }
            }
        case .functionCall(let callee, let arguments):
            return validate(callee) + arguments.flatMap { validate($0.value) }
        case .closure(let closure):
            return closure.body.flatMap(validate)
        case .memberAccess(let base, _, _):
            return validate(base)
        case .optionalChaining(let base, _):
            return validate(base)
        case .forceUnwrap(let expr):
            return validate(expr)
        case .subscript(let base, let index):
            return validate(base) + validate(index)
        case .binding(let binding):
            if binding.variableName.isEmpty { return [Issue(kind: .error, message: "Empty binding name")] }
            return []
        case .stateProjection(let projection):
            if projection.baseName.isEmpty { return [Issue(kind: .error, message: "Empty state projection")] }
            return []
        case .unknown(let reason):
            return [Issue(kind: .warning, message: "Unknown expression: \(reason)")]
        case .try(let expr):
            return validate(expr)
        case .await(let expr):
            return validate(expr)
        case .view(let view):
            return validate(view)
        }
    }
}
