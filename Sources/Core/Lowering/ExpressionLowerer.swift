import Foundation
import SwiftSyntax

/// Converts SwiftSyntax expressions to semantic IR expressions.
/// This is the core of the compiler's lowering phase.
/// RULE: No .description fallbacks. Every expression type must be explicitly handled.
public class ExpressionLowerer {
    private let context: LoweringContext
    private var statementLowerer: StatementLowerer?
    private var viewLowerer: ViewLowerer?
    
    /// Known Swift namespaces for member access kind inference
    private static let knownStaticNamespaces: Set<String> = [
        "Color", "Font", "Animation", "Edge", "Gradient",
        "UnitPoint", "Angle", "CGSize", "CGPoint", "CGRect"
    ]
    
    /// Known Swift enum namespaces for enum case inference
    private static let knownEnumNamespaces: Set<String> = [
        "Alignment", "HorizontalAlignment", "VerticalAlignment",
        "TextAlignment", "ContentMode", "BlendMode",
        "RoundedCornerStyle", "LayoutDirection"
    ]
    
    public init(context: LoweringContext) {
        self.context = context
    }
    
    /// Set the statement lowerer for closure body lowering (breaks circular dependency)
    public func setStatementLowerer(_ lowerer: StatementLowerer) {
        self.statementLowerer = lowerer
    }
    
    public func setViewLowerer(_ lowerer: ViewLowerer) {
        self.viewLowerer = lowerer
    }
    
    // MARK: - Main Entry Point
    
    public func lower(_ exprSyntax: ExprSyntaxProtocol) -> IRExpression {
        // Literals
        if let literal = exprSyntax.as(StringLiteralExprSyntax.self) {
            return lowerStringLiteral(literal)
        }
        
        if let literal = exprSyntax.as(IntegerLiteralExprSyntax.self) {
            if let value = Double(literal.literal.text) {
                return .numberLiteral(value)
            }
        }
        
        if let literal = exprSyntax.as(FloatLiteralExprSyntax.self) {
            if let value = Double(literal.literal.text) {
                return .numberLiteral(value)
            }
        }
        
        if let literal = exprSyntax.as(BooleanLiteralExprSyntax.self) {
            return .boolLiteral(literal.literal.text == "true")
        }
        
        if exprSyntax.is(NilLiteralExprSyntax.self) {
            return .nilLiteral
        }
        
        // Collections
        if let arrayExpr = exprSyntax.as(ArrayExprSyntax.self) {
            let elements = arrayExpr.elements.map { element -> IRExpression in
                lower(element.expression)
            }
            return .array(elements)
        }
        
        if let dictExpr = exprSyntax.as(DictionaryExprSyntax.self) {
            let pairs = dictExpr.content.as(DictionaryElementListSyntax.self)?.map { element -> (String, IRExpression) in
                let key: String
                if let stringKey = element.key.as(StringLiteralExprSyntax.self) {
                    key = stringKey.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
                } else if let identKey = element.key.as(DeclReferenceExprSyntax.self) {
                    key = identKey.baseName.text
                } else {
                    key = "key"
                }
                let value = lower(element.value)
                return (key, value)
            } ?? []
            return .dictionary(pairs)
        }
        
        // Tuple
        if let tupleExpr = exprSyntax.as(TupleExprSyntax.self) {
            let elements = tupleExpr.elements.map { lower($0.expression) }
            // Single-element tuple is just parenthesization, unwrap it
            if elements.count == 1 {
                return elements[0]
            }
            return .tuple(elements)
        }
        
        // Identifiers
        if let ident = exprSyntax.as(DeclReferenceExprSyntax.self) {
            let name = ident.baseName.text
            if name == "self" {
                return .self
            }
            
            // Binding / Projected value detection ($name)
            if name.hasPrefix("$") {
                let baseName = String(name.dropFirst())
                let kind: IRBindingKind = inferBindingKind(baseName)
                return .binding(IRBinding(variableName: baseName, kind: kind))
            }
            
            return .identifier(name)
        }
        
        // Infix operators (binary, assignment, augmented assignment)
        if let infixExpr = exprSyntax.as(InfixOperatorExprSyntax.self) {
            return lowerInfixOperator(infixExpr)
        }
        
        // Sequence expressions (Swift parser may produce these for chained operators)
        if let seqExpr = exprSyntax.as(SequenceExprSyntax.self) {
            return lowerSequenceExpression(seqExpr)
        }
        
        // Prefix operators
        if let prefixExpr = exprSyntax.as(PrefixOperatorExprSyntax.self) {
            return lowerPrefixOperator(prefixExpr)
        }
        
        // Postfix operators (optional chaining, force unwrap)
        if let postfixExpr = exprSyntax.as(PostfixOperatorExprSyntax.self) {
            return lowerPostfixOperator(postfixExpr)
        }
        
        // Optional chaining via member access
        if let optionalChain = exprSyntax.as(OptionalChainingExprSyntax.self) {
            let base = lower(optionalChain.expression)
            return .forceUnwrap(base) // Will be handled as optional chain in context
        }
        
        // Function calls
        if let funcCall = exprSyntax.as(FunctionCallExprSyntax.self) {
            // 1. Try to lower as a View first
            if let viewLowerer = viewLowerer,
               let viewNode = viewLowerer.lowerViewExpression(funcCall) {
                return .view(viewNode)
            }
            
            // 2. Fallback to regular function call
            let callee = lower(funcCall.calledExpression)
            let arguments = funcCall.arguments.map { arg -> IRArgument in
                IRArgument(label: arg.label?.text, value: lower(arg.expression))
            }
            return .functionCall(callee: callee, arguments: arguments)
        }
        
        // Member access
        if let member = exprSyntax.as(MemberAccessExprSyntax.self) {
            return lowerMemberAccess(member)
        }
        
        // Closures
        if let closureExpr = exprSyntax.as(ClosureExprSyntax.self) {
            return lowerClosure(closureExpr)
        }
        
        // Subscript
        if let subscriptExpr = exprSyntax.as(SubscriptCallExprSyntax.self) {
            let base = lower(subscriptExpr.calledExpression)
            if let firstArg = subscriptExpr.arguments.first {
                let index = lower(firstArg.expression)
                return .subscript(base: base, index: index)
            }
        }
        
        // Try expression
        if let tryExpr = exprSyntax.as(TryExprSyntax.self) {
            return .try(lower(tryExpr.expression))
        }
        
        // Await expression
        if let awaitExpr = exprSyntax.as(AwaitExprSyntax.self) {
            return .await(lower(awaitExpr.expression))
        }
        
        // Ternary conditional
        if let ternaryExpr = exprSyntax.as(TernaryExprSyntax.self) {
            let condition = lower(ternaryExpr.condition)
            let thenExpr = lower(ternaryExpr.thenExpression)
            let elseExpr = lower(ternaryExpr.elseExpression)
            return .ternary(condition: condition, thenExpr: thenExpr, elseExpr: elseExpr)
        }
        
        // As/is expressions — lower the inner expression
        if let asExpr = exprSyntax.as(AsExprSyntax.self) {
            return lower(asExpr.expression)
        }
        
        if let isExpr = exprSyntax.as(IsExprSyntax.self) {
            return lower(isExpr.expression)
        }
        
        // If expressions (ternary-like in Swift 5.9+)
        if let ifExpr = exprSyntax.as(IfExprSyntax.self) {
            return lowerIfExpression(ifExpr)
        }
        
        // Switch expressions
        if let switchExpr = exprSyntax.as(SwitchExprSyntax.self) {
            context.addDiagnostic("Switch expressions not yet fully supported in expression context")
            return .unknown(reason: "Switch expressions not yet supported")
        }
        
        // Fallback — emit diagnostic and return .unknown
        let typeName = "\(type(of: exprSyntax))"
        context.addDiagnostic("Unhandled expression type: \(typeName)")
        return .unknown(reason: "Unhandled expression type: \(typeName)")
    }
    
    // MARK: - String Literal Lowering (with interpolation)
    
    private func lowerStringLiteral(_ literal: StringLiteralExprSyntax) -> IRExpression {
        var parts: [IRInterpolatedPart] = []
        var hasInterpolation = false
        
        for segment in literal.segments {
            if let textSegment = segment.as(StringSegmentSyntax.self) {
                parts.append(.literal(textSegment.content.text))
            } else if let exprSegment = segment.as(ExpressionSegmentSyntax.self) {
                hasInterpolation = true
                for labeledExpr in exprSegment.expressions {
                    parts.append(.expression(lower(labeledExpr.expression)))
                }
            }
        }
        
        if hasInterpolation {
            return .interpolatedString(parts)
        }
        
        // Plain string — join all literal parts
        let text = parts.compactMap { part -> String? in
            if case .literal(let text) = part { return text }
            return nil
        }.joined()
        return .stringLiteral(text)
    }
    
    // MARK: - Infix Operator Lowering
    
    private func lowerInfixOperator(_ infix: InfixOperatorExprSyntax) -> IRExpression {
        let lhs = lower(infix.leftOperand)
        let rhs = lower(infix.rightOperand)
        
        // Assignment: =
        if infix.operator.is(AssignmentExprSyntax.self) {
            return .assignment(target: lhs, value: rhs)
        }
        
        // Operator reference (binary op or augmented assignment)
        if let opRef = infix.operator.as(BinaryOperatorExprSyntax.self) {
            let opText = opRef.operator.text
            
            // Check if it's an augmented assignment
            if let augOp = IRAugmentedAssignmentOperator.from(opText) {
                return .augmentedAssignment(target: lhs, op: augOp, value: rhs)
            }
            
            // Regular binary operator
            let op = IRBinaryOperator.from(opText)
            return .binary(lhs: lhs, op: op, rhs: rhs)
        }
        
        // Fallback for unknown operator shapes
        context.addDiagnostic("Unknown infix operator shape: \(type(of: infix.operator))")
        return .unknown(reason: "Unknown infix operator shape: \(type(of: infix.operator))")
    }
    
    // MARK: - Sequence Expression Lowering
    
    private func lowerSequenceExpression(_ seq: SequenceExprSyntax) -> IRExpression {
        let elements = Array(seq.elements)
        
        // Single element
        if elements.count == 1 {
            return lower(elements[0])
        }
        
        // Three elements: lhs op rhs
        if elements.count == 3 {
            let lhs = lower(elements[0])
            let rhs = lower(elements[2])
            
            // Assignment
            if elements[1].is(AssignmentExprSyntax.self) {
                return .assignment(target: lhs, value: rhs)
            }
            
            // Binary/augmented operator
            if let opExpr = elements[1].as(BinaryOperatorExprSyntax.self) {
                let opText = opExpr.operator.text
                if let augOp = IRAugmentedAssignmentOperator.from(opText) {
                    return .augmentedAssignment(target: lhs, op: augOp, value: rhs)
                }
                return .binary(lhs: lhs, op: IRBinaryOperator.from(opText), rhs: rhs)
            }
            
            // Ternary
            if elements[1].is(UnresolvedTernaryExprSyntax.self) {
                // elements[0] = condition, elements[1] = ? then :, elements[2] = else
                // Swift syntax represents ternary differently; this is a simplification
                return .ternary(condition: lhs, thenExpr: .unknown(reason: "Ternary then part unresolved in sequence"), elseExpr: rhs)
            }
        }
        
        // For longer sequences, fold left-to-right (simplified)
        if elements.count >= 3 {
            var result = lower(elements[0])
            var i = 1
            while i + 1 < elements.count {
                let opElement = elements[i]
                let rhsElement = elements[i + 1]
                let rhs = lower(rhsElement)
                
                if let opExpr = opElement.as(BinaryOperatorExprSyntax.self) {
                    let opText = opExpr.operator.text
                    result = .binary(lhs: result, op: IRBinaryOperator.from(opText), rhs: rhs)
                }
                i += 2
            }
            return result
        }
        
        context.addDiagnostic("Could not fold sequence expression with \(elements.count) elements")
        return .unknown(reason: "Sequence folding failed")
    }
    
    // MARK: - Prefix Operator Lowering
    
    private func lowerPrefixOperator(_ prefix: PrefixOperatorExprSyntax) -> IRExpression {
        let operand = lower(prefix.expression)
        let opText = prefix.operator.text
        let op = IRUnaryOperator.from(opText)
        return .unary(op: op, expr: operand)
    }
    
    // MARK: - Postfix Operator Lowering
    
    private func lowerPostfixOperator(_ postfix: PostfixOperatorExprSyntax) -> IRExpression {
        let operand = lower(postfix.expression)
        let opText = postfix.operator.text
        
        if opText == "!" {
            return .forceUnwrap(operand)
        }
        
        // Other postfix operators are rare; treat as the operand
        context.addDiagnostic("Unknown postfix operator: \(opText)")
        return .unknown(reason: "Unknown postfix operator: \(opText)")
    }
    
    // MARK: - Member Access Lowering
    
    private func lowerMemberAccess(_ member: MemberAccessExprSyntax) -> IRExpression {
        let memberName = member.declName.baseName.text
        
        // Implicit member access (no base): e.g., .leading, .center
        guard let base = member.base else {
            return .memberAccess(
                base: .self,
                member: memberName,
                kind: .implicit
            )
        }
        
        let baseExpr = lower(base)
        let kind = inferMemberAccessKind(base: base, member: memberName)
        
        return .memberAccess(base: baseExpr, member: memberName, kind: kind)
    }
    
    /// Infer the semantic kind of a member access from context
    private func inferMemberAccessKind(base: ExprSyntaxProtocol, member: String) -> IRMemberAccessKind {
        // If base is a known type name, determine static vs enum
        if let ident = base.as(DeclReferenceExprSyntax.self) {
            let baseName = ident.baseName.text
            
            if Self.knownEnumNamespaces.contains(baseName) {
                return .enumCase
            }
            if Self.knownStaticNamespaces.contains(baseName) {
                return .staticMember
            }
            // Uppercase first letter suggests type (static/enum), lowercase suggests instance
            if baseName.first?.isUppercase == true {
                return .staticMember
            }
            return .instance
        }
        
        // Default to unknown — type analysis in Phase D will refine
        return .unknown
    }
    
    // MARK: - Closure Lowering
    
    private func lowerClosure(_ closure: ClosureExprSyntax) -> IRExpression {
        // Extract parameters
        var parameters: [IRClosureParameter] = []
        
        if let signature = closure.signature {
            if let paramClause = signature.parameterClause {
                // Explicit parameter list: { (x: Int, y: Int) in ... }
                if let paramList = paramClause.as(ClosureShorthandParameterListSyntax.self) {
                    for param in paramList {
                        parameters.append(IRClosureParameter(name: param.name.text))
                    }
                }
                if let parameterClause = paramClause.as(ClosureParameterClauseSyntax.self) {
                    for param in parameterClause.parameters {
                        // Avoid .description by inspecting the TypeSyntax
                        let typeName: String?
                        if let type = param.type {
                            typeName = lowerType(type)
                        } else {
                            typeName = nil
                        }
                        parameters.append(IRClosureParameter(name: param.firstName.text, type: typeName))
                    }
                }
            }
        }
        
        // Lower body statements
        var bodyStatements: [IRStatement] = []
        if let stmtLowerer = statementLowerer {
            for stmt in closure.statements {
                bodyStatements.append(stmtLowerer.lowerCodeBlockItem(stmt))
            }
        } else {
            // Fallback: lower as expression statements
            for stmt in closure.statements {
                if let exprStmt = stmt.item.as(ExpressionStmtSyntax.self) {
                    bodyStatements.append(.expression(lower(exprStmt.expression)))
                } else if let expr = stmt.item.as(ExprSyntax.self) {
                    bodyStatements.append(.expression(lower(expr)))
                }
            }
        }
        
        let closureExpr = IRClosureExpression(
            parameters: parameters,
            body: bodyStatements
        )
        return .closure(closureExpr)
    }
    
    // MARK: - Type Lowering
    
    private func lowerType(_ typeSyntax: TypeSyntax) -> String {
        if let ident = typeSyntax.as(IdentifierTypeSyntax.self) {
            return ident.name.text
        }
        if let optional = typeSyntax.as(OptionalTypeSyntax.self) {
            return lowerType(optional.wrappedType) + "?"
        }
        if let array = typeSyntax.as(ArrayTypeSyntax.self) {
            return "[" + lowerType(array.element) + "]"
        }
        return "unknown"
    }
    
    // MARK: - If Expression Lowering (Swift 5.9+ if expressions)
    
    private func lowerIfExpression(_ ifExpr: IfExprSyntax) -> IRExpression {
        // Lower condition
        let condition: IRExpression
        if let firstCond = ifExpr.conditions.first,
           let condExpr = firstCond.condition.as(ExprSyntax.self) {
            condition = lower(condExpr)
        } else {
            condition = .boolLiteral(true)
        }
        
        // For if-expressions used as values, we model as ternary
        // Full support requires block expressions in IR
        return .ternary(
            condition: condition,
            thenExpr: .unknown(reason: "If-expression then branch not yet lowered"),
            elseExpr: .unknown(reason: "If-expression else branch not yet lowered")
        )
    }
    
    private func inferBindingKind(_ baseName: String) -> IRBindingKind {
        guard let symbol = context.symbolTable.lookup(baseName) else {
            return .local
        }
        
        switch symbol.kind {
        case .stateVariable: return .state
        case .localBinding: return .environment
        default: return .local
        }
    }
}

// MARK: - Operator Factory Extensions

extension IRBinaryOperator {
    static func from(_ text: String) -> IRBinaryOperator {
        switch text {
        case "+": return .add
        case "-": return .subtract
        case "*": return .multiply
        case "/": return .divide
        case "%": return .modulo
        case "==": return .equals
        case "!=": return .notEquals
        case "<": return .lessThan
        case ">": return .greaterThan
        case "<=": return .lessThanOrEqual
        case ">=": return .greaterThanOrEqual
        case "&&": return .logicalAnd
        case "||": return .logicalOr
        case "??": return .nilCoalescing
        case "...": return .closedRange
        case "..<": return .halfOpenRange
        default: return .add
        }
    }
}

extension IRUnaryOperator {
    static func from(_ text: String) -> IRUnaryOperator {
        switch text {
        case "!": return .not
        case "-": return .negate
        case "+": return .plus
        case "~": return .bitwiseNot
        default: return .not
        }
    }
}

extension IRAugmentedAssignmentOperator {
    /// Attempt to parse an augmented assignment operator from text. Returns nil for non-assignment operators.
    static func from(_ text: String) -> IRAugmentedAssignmentOperator? {
        switch text {
        case "+=": return .addAssign
        case "-=": return .subtractAssign
        case "*=": return .multiplyAssign
        case "/=": return .divideAssign
        case "%=": return .moduloAssign
        default: return nil
        }
    }
}
