import Foundation
import SwiftSyntax

/// Converts SwiftSyntax statements to semantic IR statements.
/// RULE: No .description fallbacks for semantic content. Every statement type must be explicitly handled.
public class StatementLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer
    
    public init(context: LoweringContext, exprLowerer: ExpressionLowerer) {
        self.context = context
        self.exprLowerer = exprLowerer
    }
    
    // MARK: - Statement Lowering
    
    public func lower(_ stmtSyntax: StmtSyntaxProtocol) -> IRStatement {
        if let exprStmt = stmtSyntax.as(ExpressionStmtSyntax.self) {
            // `if` in statement position (e.g. a method body) is a JS if-statement
            if let ifExpr = exprStmt.expression.as(IfExprSyntax.self) {
                return lowerIfExpression(ifExpr)
            }
            return .expression(exprLowerer.lower(exprStmt.expression))
        }
        
        if let ifExpr = stmtSyntax.as(IfExprSyntax.self) {
            return lowerIfExpression(ifExpr)
        }
        
        if let guardStmt = stmtSyntax.as(GuardStmtSyntax.self) {
            return lowerGuardStatement(guardStmt)
        }
        
        if let switchExpr = stmtSyntax.as(SwitchExprSyntax.self) {
            return lowerSwitchExpression(switchExpr)
        }
        
        if let forStmt = stmtSyntax.as(ForStmtSyntax.self) {
            return lowerForLoop(forStmt)
        }
        
        if let whileStmt = stmtSyntax.as(WhileStmtSyntax.self) {
            return lowerWhileLoop(whileStmt)
        }
        
        if stmtSyntax.is(BreakStmtSyntax.self) {
            return .breakStatement
        }
        
        if stmtSyntax.is(ContinueStmtSyntax.self) {
            return .continueStatement
        }
        
        if let returnStmt = stmtSyntax.as(ReturnStmtSyntax.self) {
            let value = returnStmt.expression.map { exprLowerer.lower($0) }
            return .returnStatement(value)
        }
        
        context.addDiagnostic("not yet supported: statement \(stmtSyntax.kind)", at: stmtSyntax)
        return .expression(.identifier("/* unknown statement */"))
    }
    
    // MARK: - Code Block Item Lowering
    
    /// Lower a `CodeBlockItemSyntax` — handles both statements and declarations
    public func lowerCodeBlockItem(_ item: CodeBlockItemSyntax) -> IRStatement {
        // Variable declarations
        if let varDecl = item.item.as(VariableDeclSyntax.self) {
            return lowerVariableDeclaration(varDecl)
        }
        
        // Statements
        if let stmt = item.item.as(StmtSyntax.self) {
            // StmtSyntax protocol — delegate
            return lower(stmt)
        }
        
        // Expression statements
        if let expr = item.item.as(ExprSyntax.self) {
            return .expression(exprLowerer.lower(expr))
        }
        
        context.addDiagnostic("not yet supported: \(item.item.kind)", at: item)
        return .expression(.identifier("/* unknown code block item */"))
    }
    
    // MARK: - Variable Declaration
    
    private func lowerVariableDeclaration(_ varDecl: VariableDeclSyntax) -> IRStatement {
        let isLet = varDecl.bindingSpecifier.text == "let"
        
        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.addDiagnostic("not yet supported: destructuring variable pattern", at: varDecl)
            return .expression(.identifier("/* complex var decl */"))
        }
        
        let name = pattern.identifier.text
        let value: IRExpression
        
        if let initializer = binding.initializer {
            value = exprLowerer.lower(initializer.value)
        } else {
            value = .nilLiteral
        }
        
        // Register in context
        context.registerVariable(name, value: value)
        
        return .variableDeclaration(name: name, isLet: isLet, value: value)
    }
    
    // MARK: - If Statement
    
    private func lowerIfExpression(_ ifExpr: IfExprSyntax) -> IRStatement {
        // `if let x = …` declares x in a block around the if, like Swift's scoping
        let binding = lowerBinding(in: ifExpr.conditions)
        let condition = binding?.condition ?? lowerConditionList(ifExpr.conditions)
        
        // Lower then branch
        let thenBranch = lowerCodeBlock(ifExpr.body)
        
        // Lower else branch
        let elseBranch: [IRStatement]?
        if let elseBody = ifExpr.elseBody {
            if let elseIf = elseBody.as(IfExprSyntax.self) {
                // else if → nested if statement
                elseBranch = [lowerIfExpression(elseIf)]
            } else if let elseBlock = elseBody.as(CodeBlockSyntax.self) {
                elseBranch = lowerCodeBlock(elseBlock)
            } else {
                elseBranch = nil
            }
        } else {
            elseBranch = nil
        }
        
        let ifStatement = IRStatement.ifStatement(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
        if let declaration = binding?.declaration {
            return .block([declaration, ifStatement])
        }
        return ifStatement
    }

    /// One optional binding (`let x = value` or `let x`) plus boolean conditions:
    /// the declaration to emit first and the full check. nil when there is no binding.
    /// `firstIndex(where:)` maps to findIndex, which signals "nil" with -1.
    private func lowerBinding(in conditions: ConditionElementListSyntax)
        -> (declaration: IRStatement?, condition: IRExpression)? {
        let bindings = conditions.compactMap { $0.condition.as(OptionalBindingConditionSyntax.self) }
        guard let binding = bindings.first else { return nil }
        guard bindings.count == 1, let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            context.addDiagnostic("not yet supported: several optional bindings in one condition", at: conditions)
            return nil
        }

        var declaration: IRStatement?
        var check = IRExpression.binary(lhs: .identifier(name), op: .notNil, rhs: .nilLiteral)
        if let value = binding.initializer?.value {
            if let call = value.as(FunctionCallExprSyntax.self),
               let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base,
               member.declName.baseName.text == "firstIndex",
               let predicate = call.trailingClosure.map(ExprSyntax.init)
                ?? call.arguments.first(where: { $0.label?.text == "where" })?.expression {
                let findIndex = IRExpression.functionCall(
                    callee: .memberAccess(base: exprLowerer.lower(base), member: "findIndex", kind: .instance),
                    arguments: [IRArgument(value: exprLowerer.lower(predicate))])
                declaration = .variableDeclaration(name: name, isLet: true, value: findIndex)
                check = .binary(lhs: .identifier(name), op: .notEquals, rhs: .numberLiteral(-1))
            } else {
                declaration = .variableDeclaration(name: name, isLet: true, value: exprLowerer.lower(value))
            }
        }

        let others = conditions.filter { !$0.condition.is(OptionalBindingConditionSyntax.self) }
        let rest = lowerConditionList(ConditionElementListSyntax(others))
        if case .boolLiteral(true) = rest { return (declaration, check) }
        return (declaration, .binary(lhs: check, op: .logicalAnd, rhs: rest))
    }
    
    // MARK: - Guard Statement
    
    private func lowerGuardStatement(_ guardStmt: GuardStmtSyntax) -> IRStatement {
        // `guard let x = …` keeps x in scope after the guard, so no block
        let binding = lowerBinding(in: guardStmt.conditions)
        let condition = binding?.condition ?? lowerConditionList(guardStmt.conditions)
        let guardStatement = IRStatement.guardStatement(condition: condition, body: lowerCodeBlock(guardStmt.body))
        if let declaration = binding?.declaration {
            return .sequence([declaration, guardStatement])
        }
        return guardStatement
    }
    
    // MARK: - Switch Statement
    
    private func lowerSwitchExpression(_ switchExpr: SwitchExprSyntax) -> IRStatement {
        let subject = exprLowerer.lower(switchExpr.subject)
        
        var cases: [IRSwitchCase] = []
        for caseItem in switchExpr.cases {
            if let switchCase = caseItem.as(SwitchCaseSyntax.self) {
                cases.append(lowerSwitchCase(switchCase))
            }
        }
        
        return .switchStatement(value: subject, cases: cases)
    }
    
    private func lowerSwitchCase(_ switchCase: SwitchCaseSyntax) -> IRSwitchCase {
        let pattern: IRSwitchPattern
        
        if let caseLabel = switchCase.label.as(SwitchCaseLabelSyntax.self) {
            // Get first case item expression
            if let firstItem = caseLabel.caseItems.first,
               let exprPattern = firstItem.pattern.as(ExpressionPatternSyntax.self) {
                pattern = .expression(exprLowerer.lower(exprPattern.expression))
            } else if let firstItem = caseLabel.caseItems.first,
                      let identPattern = firstItem.pattern.as(IdentifierPatternSyntax.self) {
                pattern = .expression(.identifier(identPattern.identifier.text))
            } else {
                pattern = .expression(.identifier("/* pattern */"))
            }
        } else if switchCase.label.is(SwitchDefaultLabelSyntax.self) {
            pattern = .default
        } else {
            pattern = .default
        }
        
        let body = switchCase.statements.map { lowerCodeBlockItem($0) }
        
        return IRSwitchCase(pattern: pattern, body: body)
    }
    
    // MARK: - For Loop
    
    private func lowerForLoop(_ forStmt: ForStmtSyntax) -> IRStatement {
        // Extract loop variable name from pattern
        let variable: String
        if let identPattern = forStmt.pattern.as(IdentifierPatternSyntax.self) {
            variable = identPattern.identifier.text
        } else if let wildcardPattern = forStmt.pattern.as(WildcardPatternSyntax.self) {
            variable = "_"
        } else if let tuplePattern = forStmt.pattern.as(TuplePatternSyntax.self) {
            // Simplified: join tuple elements
            let elements = tuplePattern.elements.map { element -> String in
                if let ident = element.pattern.as(IdentifierPatternSyntax.self) {
                    return ident.identifier.text
                }
                return "_"
            }
            variable = elements.joined(separator: ", ")
        } else {
            // Fallback for complex patterns
            variable = "_"
            context.addDiagnostic("not yet supported: for-in pattern", at: forStmt.pattern)
        }
        
        let sequence = exprLowerer.lower(forStmt.sequence)
        let body = lowerCodeBlock(forStmt.body)
        
        return .forLoop(variable: variable, sequence: sequence, body: body)
    }
    
    // MARK: - While Loop
    
    private func lowerWhileLoop(_ whileStmt: WhileStmtSyntax) -> IRStatement {
        let condition = lowerConditionList(whileStmt.conditions)
        let body = lowerCodeBlock(whileStmt.body)
        return .whileLoop(condition: condition, body: body)
    }
    
    // MARK: - Helpers
    
    /// Lower a condition list (e.g., from if/guard/while)
    func lowerConditionList(_ conditions: ConditionElementListSyntax) -> IRExpression {
        var expressions: [IRExpression] = []
        
        for condition in conditions {
            if let exprCondition = condition.condition.as(ExprSyntax.self) {
                expressions.append(exprLowerer.lower(exprCondition))
            } else {
                // `if let x = …` would need x declared in the branch; patterns and availability too.
                context.addDiagnostic("not yet supported: condition \(condition.condition.trimmedDescription)", at: condition)
            }
        }
        
        // Combine multiple conditions with &&
        guard let first = expressions.first else {
            return .boolLiteral(true)
        }
        
        return expressions.dropFirst().reduce(first) { acc, expr in
            .binary(lhs: acc, op: .logicalAnd, rhs: expr)
        }
    }
    
    /// Lower a code block to a list of statements
    private func lowerCodeBlock(_ block: CodeBlockSyntax) -> [IRStatement] {
        block.statements.map { lowerCodeBlockItem($0) }
    }
}
