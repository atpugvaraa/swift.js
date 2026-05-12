//
//  IRStatement.swift
//  swiftjs
//
//  Intermediate Representation of Swift statements
//

import Foundation

/// Intermediate representation of a Swift statement
/// Covers control flow, assignments, declarations, etc.
public indirect enum IRStatement {
    // MARK: - Expression
    case expression(IRExpression)
    
    // MARK: - Variable Declarations
    case variableDeclaration(name: String, isLet: Bool, value: IRExpression)
    
    // MARK: - Legacy Assignment (kept for backward compat, prefer IRExpression.assignment)
    case assignment(variable: String, value: IRExpression)
    case augmentedAssignment(variable: String, op: String, value: IRExpression)
    
    // MARK: - Control Flow
    case ifStatement(condition: IRExpression, thenBranch: [IRStatement], elseBranch: [IRStatement]?)
    case guardStatement(condition: IRExpression, body: [IRStatement])
    case switchStatement(value: IRExpression, cases: [IRSwitchCase])
    case forLoop(variable: String, sequence: IRExpression, body: [IRStatement])
    case whileLoop(condition: IRExpression, body: [IRStatement])
    
    // MARK: - Return/Break/Continue
    case returnStatement(IRExpression?)
    case breakStatement
    case continueStatement
}

// MARK: - Supporting Types

/// Pattern in a switch case
public enum IRSwitchPattern {
    /// Matches a specific expression value
    case expression(IRExpression)
    
    /// The default/wildcard case
    case `default`
}

/// A case in a switch statement
public class IRSwitchCase: BaseIRNode {
    public let pattern: IRSwitchPattern
    public let body: [IRStatement]
    
    public init(
        pattern: IRSwitchPattern,
        body: [IRStatement] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.pattern = pattern
        self.body = body
        super.init(sourceLocation: sourceLocation)
    }
}
