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
            if name.hasPrefix("$"), !name.dropFirst().allSatisfy(\.isNumber) {  // $0 is a closure parameter
                let baseName = String(name.dropFirst())
                let kind: IRBindingKind = inferBindingKind(baseName)
                // Emitted as a one-way value today; two-way bindings need value + onChange.
                context.addDiagnostic("not yet supported: binding \(name)", at: exprSyntax)
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
        if exprSyntax.is(OptionalChainingExprSyntax.self) {
            return unsupported("optional chaining ?.", at: exprSyntax)
        }
        
        // Function calls
        if let funcCall = exprSyntax.as(FunctionCallExprSyntax.self) {
            // 1. Try to lower as a View first
            if let viewLowerer = viewLowerer,
               let viewNode = viewLowerer.lowerViewExpression(funcCall) {
                return .view(viewNode)
            }
            
            if let mapped = lowerLibraryCall(funcCall) {
                return mapped
            }

            // 2. Calls to the View's own methods are emitted as-is. Other calls (methods,
            //    initializers, functions) have no JS mapping yet, e.g. `isOn.toggle()` or `UUID()`.
            let calleeName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text
                ?? funcCall.calledExpression.as(MemberAccessExprSyntax.self).flatMap { member in
                    member.base?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.self)
                        ? member.declName.baseName.text : nil
                }
            let isViewMethod = calleeName.map { context.viewMethods.contains($0) } ?? false
            // Mutating methods on @State values are rewritten into setter calls by StateLoweringPass.
            let isStateMutation = funcCall.calledExpression.as(MemberAccessExprSyntax.self).map {
                Self.mutatingMethods.contains($0.declName.baseName.text) && $0.base.map(isStateRooted) == true
            } ?? false
            if !isViewMethod && !isStateMutation {
                context.addDiagnostic(
                    "not yet supported: call to \(funcCall.calledExpression.trimmedDescription)()", at: funcCall)
            }
            let callee = lower(funcCall.calledExpression)
            var arguments = funcCall.arguments.map { arg -> IRArgument in
                IRArgument(label: arg.label?.text, value: lower(arg.expression))
            }
            if let trailing = funcCall.trailingClosure {
                arguments.append(IRArgument(value: lower(ExprSyntax(trailing))))
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
        if exprSyntax.is(SwitchExprSyntax.self) {
            return unsupported("switch expression", at: exprSyntax)
        }
        
        // Fallback — emit diagnostic and return .unknown
        return unsupported("expression \(exprSyntax.kind)", at: exprSyntax)
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
            guard let op = IRBinaryOperator.from(opText) else {
                return unsupported("operator \(opText)", at: infix)
            }
            return .binary(lhs: lhs, op: op, rhs: rhs)
        }
        
        // Fallback for unknown operator shapes
        return unsupported("operator \(infix.operator.trimmedDescription)", at: infix)
    }
    
    // MARK: - Sequence Expression Lowering
    
    private func lowerSequenceExpression(_ seq: SequenceExprSyntax) -> IRExpression {
        // Operator folding left this unfolded, so it uses an operator outside Swift's standard set.
        return unsupported("expression with a custom operator", at: seq)
    }
    
    // MARK: - Prefix Operator Lowering
    
    private func lowerPrefixOperator(_ prefix: PrefixOperatorExprSyntax) -> IRExpression {
        let operand = lower(prefix.expression)
        let opText = prefix.operator.text
        guard let op = IRUnaryOperator.from(opText) else {
            return unsupported("prefix operator \(opText)", at: prefix)
        }
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
        return unsupported("postfix operator \(opText)", at: postfix)
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
        
        // self.count -> count (component members are locals in a function component)
        if base.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.self) {
            return .identifier(memberName)
        }

        let baseExpr = lower(base)
        let kind = inferMemberAccessKind(base: base, member: memberName)

        // Swift collection/String properties with a different name in JS
        if kind == .instance || kind == .unknown {
            let length = IRExpression.memberAccess(base: baseExpr, member: "length", kind: .instance)
            switch memberName {
            case "count": return length
            case "isEmpty": return .binary(lhs: length, op: .equals, rhs: .numberLiteral(0))
            case "first": return .subscript(base: baseExpr, index: .numberLiteral(0))
            case "last": return .subscript(base: baseExpr, index: .binary(lhs: length, op: .subtract, rhs: .numberLiteral(1)))
            default: break
            }
        }
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
    
    /// Swift standard library calls with a JS equivalent of the same meaning, or nil.
    private func lowerLibraryCall(_ call: FunctionCallExprSyntax) -> IRExpression? {
        // Match on syntax first; arguments are lowered only for a match, so a fallback
        // lowering of the same call doesn't report their diagnostics twice.
        var argumentSyntax = call.arguments.map { (label: $0.label?.text, expr: $0.expression) }
        if let trailing = call.trailingClosure {
            argumentSyntax.append((label: nil, expr: ExprSyntax(trailing)))
        }
        let labels = argumentSyntax.map(\.label)
        let isClosureArgument = argumentSyntax.first?.expr.is(ClosureExprSyntax.self) ?? false
        var lowered: [IRArgument]?
        var values: [IRArgument] {
            if lowered == nil { lowered = argumentSyntax.map { IRArgument(value: lower($0.expr)) } }
            return lowered!
        }

        // Free functions and initializers
        if let name = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text {
            // Model memberwise init: Todo(title: x) -> Todo({ title: x })
            if context.modelTypes.contains(name), labels.allSatisfy({ $0 != nil }) {
                let fields = zip(argumentSyntax, values).map { ($0.label!, $1.value) }
                return .functionCall(callee: .identifier(name),
                                     arguments: fields.isEmpty ? [] : [IRArgument(value: .dictionary(fields))])
            }
            switch (name, labels) {
            case ("UUID", []):
                return .functionCall(callee: .identifier("crypto.randomUUID"), arguments: [])
            case ("String", [nil]):
                return .functionCall(callee: .identifier("String"), arguments: values)
            default:
                return nil
            }
        }

        guard let member = call.calledExpression.as(MemberAccessExprSyntax.self), let baseSyntax = member.base,
              baseSyntax.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind != .keyword(.self) else { return nil }
        let method = { (name: String, args: [IRArgument]) in
            IRExpression.functionCall(
                callee: .memberAccess(base: self.lower(baseSyntax), member: name, kind: .instance), arguments: args)
        }
        switch (member.declName.baseName.text, labels) {
        case ("filter", [nil]), ("map", [nil]), ("forEach", [nil]):
            return method(member.declName.baseName.text, values)
        case ("contains", [nil]) where !isClosureArgument:
            return method("includes", values)
        case ("contains", ["where"]), ("contains", [nil]):
            return method("some", values)
        case ("first", ["where"]), ("first", [nil]):
            return method("find", values)
        case ("allSatisfy", [nil]):
            return method("every", values)
        case ("reduce", [nil, nil]):
            return method("reduce", [values[1], values[0]])  // JS takes (callback, initial)
        case ("joined", []):
            return method("join", [IRArgument(value: .stringLiteral(""))])
        case ("joined", ["separator"]):
            return method("join", values)
        case ("reversed", []):
            return .functionCall(callee: .memberAccess(base: method("slice", []), member: "reverse", kind: .instance), arguments: [])
        case ("uppercased", []):
            return method("toUpperCase", [])
        case ("lowercased", []):
            return method("toLowerCase", [])
        case ("hasPrefix", [nil]):
            return method("startsWith", values)
        case ("hasSuffix", [nil]):
            return method("endsWith", values)
        case ("trimmingCharacters", ["in"]):
            let set = call.arguments.first?.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
            return ["whitespaces", "whitespacesAndNewlines"].contains(set ?? "") ? method("trim", []) : nil
        default:
            return nil
        }
    }

    /// Swift mutating methods StateLoweringPass knows how to rewrite on @State values.
    static let mutatingMethods: Set<String> = ["toggle", "append", "insert", "remove", "removeAll"]

    /// `todos`, `todos[i].done` … whose root is a @State variable.
    private func isStateRooted(_ expr: ExprSyntax) -> Bool {
        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            return context.lookupVariable(ref.baseName.text)?.kind == .stateVariable
        }
        if let member = expr.as(MemberAccessExprSyntax.self), let base = member.base {
            return isStateRooted(base)
        }
        if let sub = expr.as(SubscriptCallExprSyntax.self) {
            return isStateRooted(sub.calledExpression)
        }
        return false
    }

    /// Records valid Swift that cannot be translated yet and returns a placeholder that is never emitted.
    private func unsupported(_ what: String, at node: some SyntaxProtocol) -> IRExpression {
        context.addDiagnostic("not yet supported: \(what)", at: node)
        return .unknown(reason: what)
    }

    private func lowerClosure(_ closure: ClosureExprSyntax) -> IRExpression {
        var parameters: [IRClosureParameter] = []

        if let signature = closure.signature {
            if signature.capture != nil || signature.effectSpecifiers != nil {
                context.addDiagnostic("not yet supported: closure capture list, async or throws", at: signature)
            }
            if let shorthand = signature.parameterClause?.as(ClosureShorthandParameterListSyntax.self) {
                // { a, b in … }: types come from context
                parameters = shorthand.map { IRClosureParameter(name: $0.name.text) }
            } else if let clause = signature.parameterClause?.as(ClosureParameterClauseSyntax.self) {
                // { (a: Int, b) in … }
                for param in clause.parameters {
                    var type: String?
                    if let swiftType = param.type {
                        type = context.typeScriptType(swiftType)
                        if type == nil {
                            context.addDiagnostic("not yet supported: closure parameter \(param.trimmedDescription)", at: param)
                        }
                    }
                    parameters.append(IRClosureParameter(name: (param.secondName ?? param.firstName).text, type: type))
                }
            }
        } else {
            // Anonymous $0, $1 … become arrow parameters up to the highest one used.
            let highest = closure.statements.tokens(viewMode: .sourceAccurate).compactMap { token -> Int? in
                guard case .dollarIdentifier(let name) = token.tokenKind else { return nil }
                return Int(name.dropFirst())
            }.max()
            if let highest {
                parameters = (0...highest).map { IRClosureParameter(name: "$\($0)") }
            }
        }

        let body = closure.statements.map { item -> IRStatement in
            statementLowerer?.lowerCodeBlockItem(item) ?? .expression(unsupported("closure body", at: item))
        }
        return .closure(IRClosureExpression(parameters: parameters, body: body))
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
        // Branch bodies are not lowered yet; report instead of emitting a broken ternary.
        return unsupported("if inside a view or expression", at: ifExpr)
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
    /// Operators with the same meaning in JS; nil for ranges and anything else.
    static func from(_ text: String) -> IRBinaryOperator? {
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
        default: return nil
        }
    }
}

extension IRUnaryOperator {
    static func from(_ text: String) -> IRUnaryOperator? {
        switch text {
        case "!": return .not
        case "-": return .negate
        case "+": return .plus
        case "~": return .bitwiseNot
        default: return nil
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
