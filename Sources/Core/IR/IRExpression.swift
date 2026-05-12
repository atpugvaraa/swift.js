//
//  IRExpression.swift
//  swiftjs
//
//  Intermediate Representation of Swift expressions with semantic information
//

import Foundation

/// Intermediate representation of a Swift expression with full semantic information
public indirect enum IRExpression {
    // MARK: - Literals
    case identifier(String)
    case stringLiteral(String)
    case numberLiteral(Double)
    case boolLiteral(Bool)
    case nilLiteral
    case `self`
    
    // MARK: - Collections
    case array([IRExpression])
    case dictionary([(String, IRExpression)])
    case tuple([IRExpression])
    
    // MARK: - Operations
    case binary(lhs: IRExpression, op: IRBinaryOperator, rhs: IRExpression)
    case unary(op: IRUnaryOperator, expr: IRExpression)
    case ternary(condition: IRExpression, thenExpr: IRExpression, elseExpr: IRExpression)
    
    // MARK: - Assignment
    case assignment(target: IRExpression, value: IRExpression)
    case augmentedAssignment(target: IRExpression, op: IRAugmentedAssignmentOperator, value: IRExpression)
    
    // MARK: - String
    case interpolatedString([IRInterpolatedPart])
    
    // MARK: - Function/Closure
    case functionCall(callee: IRExpression, arguments: [IRArgument])
    case closure(IRClosureExpression)
    
    // MARK: - Property/Member access
    case memberAccess(base: IRExpression, member: String, kind: IRMemberAccessKind)
    
    // MARK: - Optional handling
    case optionalChaining(base: IRExpression, member: String)
    case forceUnwrap(IRExpression)
    
    // MARK: - Subscript
    case `subscript`(base: IRExpression, index: IRExpression)
    
    // MARK: - Async/Error handling
    case `try`(IRExpression)
    case `await`(IRExpression)
    
    // MARK: - State & Binding
    case binding(IRBinding)
    case stateProjection(IRStateProjection)
    
    // MARK: - Views
    case view(IRViewNode)
    
    // MARK: - Error Handling
    case unknown(reason: String)
}

// MARK: - Supporting Types

/// A part of an interpolated string (either literal text or expression)
public enum IRInterpolatedPart {
    case literal(String)
    case expression(IRExpression)
}

/// A function call argument with optional label
public struct IRArgument {
    public let label: String?
    public let value: IRExpression
    
    public init(label: String? = nil, value: IRExpression) {
        self.label = label
        self.value = value
    }
}

/// Binary operators in expressions (comparison, logical, arithmetic)
public enum IRBinaryOperator: String, CaseIterable {
    // Arithmetic
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"
    
    // Comparison
    case equals = "=="
    case notEquals = "!="
    case lessThan = "<"
    case greaterThan = ">"
    case lessThanOrEqual = "<="
    case greaterThanOrEqual = ">="
    
    // Logical
    case logicalAnd = "&&"
    case logicalOr = "||"
    
    // Nil coalescing
    case nilCoalescing = "??"
    
    // Range
    case closedRange = "..."
    case halfOpenRange = "..<"
    
    /// JavaScript precedence level (higher = binds tighter)
    public var precedence: Int {
        switch self {
        case .logicalOr: return 1
        case .logicalAnd: return 2
        case .nilCoalescing: return 3
        case .equals, .notEquals: return 4
        case .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual: return 5
        case .closedRange, .halfOpenRange: return 6
        case .add, .subtract: return 7
        case .multiply, .divide, .modulo: return 8
        }
    }
}

/// Unary operators in expressions
public enum IRUnaryOperator: String, CaseIterable {
    case not = "!"
    case negate = "-"
    case plus = "+"
    case bitwiseNot = "~"
}

/// Augmented assignment operators
public enum IRAugmentedAssignmentOperator: String, CaseIterable {
    case addAssign = "+="
    case subtractAssign = "-="
    case multiplyAssign = "*="
    case divideAssign = "/="
    case moduloAssign = "%="
}

/// A closure expression with parameters and body
public class IRClosureExpression: BaseIRNode {
    public let parameters: [IRClosureParameter]
    public let body: [IRStatement]
    
    public init(
        parameters: [IRClosureParameter] = [],
        body: [IRStatement] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.parameters = parameters
        self.body = body
        super.init(sourceLocation: sourceLocation)
    }
}

/// A parameter in a closure
public struct IRClosureParameter {
    public let name: String
    public let type: String?  // Optional type annotation
    
    public init(name: String, type: String? = nil) {
        self.name = name
        self.type = type
    }
}
