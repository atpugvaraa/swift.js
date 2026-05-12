import Foundation

/// Context for expression emission, providing necessary information like precedence and interpolation state.
public struct IRExpressionContext {
    /// Precedence level of the parent expression (higher = binds tighter)
    public let precedence: Int
    /// Whether we are currently inside a template literal (backticks)
    public let inTemplateLiteral: Bool
    /// Whether we are emitting a property value (JSX vs standard JS)
    public let isProperty: Bool
    
    public init(
        precedence: Int = 0,
        inTemplateLiteral: Bool = false,
        isProperty: Bool = false
    ) {
        self.precedence = precedence
        self.inTemplateLiteral = inTemplateLiteral
        self.isProperty = isProperty
    }
    
    public func with(precedence: Int) -> IRExpressionContext {
        IRExpressionContext(precedence: precedence, inTemplateLiteral: inTemplateLiteral, isProperty: isProperty)
    }
    
    public func with(inTemplateLiteral: Bool) -> IRExpressionContext {
        IRExpressionContext(precedence: precedence, inTemplateLiteral: inTemplateLiteral, isProperty: isProperty)
    }
}

/// Central authoritative engine for emitting IR expressions to TypeScript/JSX.
/// Handles operator precedence, parenthesization, and React-specific syntax (JSX braces, etc.).
public class ExpressionEmissionEngine {
    private lazy var styleEmitter: ReactStyleEmitter = {
        ReactStyleEmitter(exprEngine: self)
    }()
    
    public init() {}
    
    public func emit(_ expression: IRExpression, context: IRExpressionContext = IRExpressionContext()) -> String {
        switch expression {
        case .identifier(let name):
            return name
            
        case .stringLiteral(let value):
            return context.inTemplateLiteral ? value : "\"\(value)\""
            
        case .numberLiteral(let value):
            // Remove .0 if it's an integer
            let str = String(value)
            return str.hasSuffix(".0") ? String(str.dropLast(2)) : str
            
        case .boolLiteral(let value):
            return value ? "true" : "false"
            
        case .nilLiteral:
            return "null"
            
        case .self:
            return "this"
            
        case .array(let elements):
            let emitted = elements.map { emit($0, context: context.with(precedence: 0)) }.joined(separator: ", ")
            return "[\(emitted)]"
            
        case .dictionary(let pairs):
            let emitted = pairs.map { "\"\($0.0)\": \(emit($0.1, context: context.with(precedence: 0)))" }.joined(separator: ", ")
            return "{ \(emitted) }"
            
        case .tuple(let elements):
            // Swift tuples can be mapped to arrays or objects; default to array-like
            let emitted = elements.map { emit($0, context: context.with(precedence: 0)) }.joined(separator: ", ")
            return "[\(emitted)]"
            
        case .binary(let lhs, let op, let rhs):
            return emitBinary(lhs: lhs, op: op, rhs: rhs, context: context)
            
        case .unary(let op, let expr):
            return "\(op.rawValue)\(emit(expr, context: context.with(precedence: 14)))" // High precedence for unary
            
        case .ternary(let condition, let thenExpr, let elseExpr):
            let cond = emit(condition, context: context.with(precedence: 3))
            let then = emit(thenExpr, context: context.with(precedence: 3))
            let elze = emit(elseExpr, context: context.with(precedence: 3))
            let result = "\(cond) ? \(then) : \(elze)"
            return wrapInParentheses(result, if: context.precedence > 3)
            
        case .assignment(let target, let value):
            let t = emit(target, context: context.with(precedence: 2))
            let v = emit(value, context: context.with(precedence: 2))
            return "\(t) = \(v)"
            
        case .augmentedAssignment(let target, let op, let value):
            let t = emit(target, context: context.with(precedence: 2))
            let v = emit(value, context: context.with(precedence: 2))
            return "\(t) \(op.rawValue) \(v)"
            
        case .interpolatedString(let parts):
            let emitted = parts.map { part -> String in
                switch part {
                case .literal(let text): return text
                case .expression(let expr): return "${" + emit(expr, context: context.with(inTemplateLiteral: true)) + "}"
                }
            }.joined()
            return "`\(emitted)`"
            
        case .functionCall(let callee, let arguments):
            let calleeStr = emit(callee, context: context.with(precedence: 18)) // Highest precedence
            let argsStr = arguments.map { emit($0.value, context: context.with(precedence: 0)) }.joined(separator: ", ")
            return "\(calleeStr)(\(argsStr))"
            
        case .closure(let closure):
            let params = closure.parameters.map { $0.name }.joined(separator: ", ")
            // Body emission needs a StatementEmitter — will be integrated later
            return "(\(params)) => { /* body */ }"
            
        case .memberAccess(let base, let member, let kind):
            let baseStr = emit(base, context: context.with(precedence: 18))
            if kind == .implicit {
                return "\"\(member)\"" // e.g. .leading -> "leading"
            }
            return "\(baseStr).\(member)"
            
        case .optionalChaining(let base, let member):
            let baseStr = emit(base, context: context.with(precedence: 18))
            return "\(baseStr)?.\(member)"
            
        case .forceUnwrap(let expr):
            let exprStr = emit(expr, context: context.with(precedence: 18))
            return "\(exprStr)!" // Valid TS but risky; emitter should ideally handle this
            
        case .subscript(let base, let index):
            let baseStr = emit(base, context: context.with(precedence: 18))
            let indexStr = emit(index, context: context.with(precedence: 0))
            return "\(baseStr)[\(indexStr)]"
            
        case .try(let expr):
            return emit(expr, context: context) // 'try' is implicit in JS/TS
            
        case .await(let expr):
            return "await \(emit(expr, context: context.with(precedence: 17)))"
            
        case .binding(let binding):
            // Context decides how to emit binding (as value or as projected value)
            return binding.variableName
            
        case .stateProjection(let projection):
            return projection.projectedValue
            
        case .view(let node):
            return "/* IRViewNode emission handled by ViewEmitter */"
            
        case .unknown(let reason):
            return "/* unknown: \(reason) */"
        }
    }
    
    private func emitBinary(lhs: IRExpression, op: IRBinaryOperator, rhs: IRExpression, context: IRExpressionContext) -> String {
        let opPrecedence = op.precedence
        let left = emit(lhs, context: context.with(precedence: opPrecedence))
        let right = emit(rhs, context: context.with(precedence: opPrecedence + 1)) // Right-associative or same binds tighter on right to avoid ambiguity
        
        let result = "\(left) \(op.rawValue) \(right)"
        return wrapInParentheses(result, if: context.precedence > opPrecedence)
    }
    
    private func wrapInParentheses(_ str: String, if condition: Bool) -> String {
        condition ? "(\(str))" : str
    }
}
