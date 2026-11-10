import Foundation

/// Lowers writes to @State variables into React setter calls.
///
/// Swift mutates state in place and later statements see the new value; React setters
/// schedule a new value. To keep Swift's results:
/// - a write that uses the variable's own value is a functional update,
///   `count += 1` -> `setCount((count) => count + 1)`, so consecutive writes compose;
/// - writes below the root (`todos[i].done.toggle()`) rebuild the value immutably;
/// - mutating methods (`append`, `remove(at:)`, `toggle()` …) become new-value expressions;
/// - reading a variable after writing it in the same action would see the old value in
///   React, so it is reported.
public class StateLoweringPass: CompilerPass {
    public let name = "StateLowering"
    private var diagnostics: DiagnosticsCollector?
    private var componentName = ""

    public init() {}

    public func run(on program: IRFile, context: CompilerPassContext) throws {
        diagnostics = context.diagnostics
        for component in program.components {
            componentName = component.name
            lowerState(in: component)
        }
    }

    private func lowerState(in component: IRComponent) {
        let stateVars = Set(component.stateVariables.map { $0.name })
        if stateVars.isEmpty { return }
        component.declarations = component.declarations.map { lowerStatement($0, stateVars) }
        if let body = component.body {
            lowerView(body, stateVars)
        }
    }

    // MARK: - Views

    private func lowerView(_ node: IRViewNode, _ stateVars: Set<String>) {
        node.statements = lowerBody(node.statements, stateVars)  // Button action
        for modifier in node.modifiers {
            modifier.effects = modifier.effects.map { effect in
                switch effect {
                case .interaction(let event, let handler):
                    return .interaction(event: event, handler: lowerExpression(handler, stateVars))
                case .style(let key, let value):
                    return .style(key: key, value: lowerExpression(value, stateVars))
                default:
                    return effect
                }
            }
        }
        node.properties = node.properties.map {
            IRProperty(name: $0.name, value: lowerExpression($0.value, stateVars))
        }
        if let conditional = node as? IRConditionalViewNode {
            conditional.condition = lowerExpression(conditional.condition, stateVars)
            (conditional.thenViews + (conditional.elseViews ?? [])).forEach { lowerView($0, stateVars) }
        }
        if let forEach = node as? IRForEachViewNode {
            forEach.data = lowerExpression(forEach.data, stateVars)
            lowerView(forEach.content, stateVars)
        }
        node.children.forEach { lowerView($0, stateVars) }
    }

    // MARK: - Statements

    /// An action body (method, closure, Button action): checks stale reads, then lowers.
    private func lowerBody(_ body: [IRStatement], _ stateVars: Set<String>) -> [IRStatement] {
        var written: Set<String> = []
        for statement in body {
            var reads: Set<String> = []
            var writes: Set<String> = []
            collect(statement, stateVars, reads: &reads, writes: &writes)
            for name in reads.intersection(written).sorted() {
                diagnostics?.error(
                    "not yet supported: reading \(name) after changing it in the same action in \(componentName) "
                    + "(React state updates apply on the next render)")
            }
            written.formUnion(writes)
        }
        return body.map { lowerStatement($0, stateVars) }
    }

    private func lowerStatement(_ statement: IRStatement, _ stateVars: Set<String>) -> IRStatement {
        switch statement {
        case .expression(let expr):
            return .expression(lowerExpression(expr, stateVars))
        case .variableDeclaration(let name, let isLet, let value):
            return .variableDeclaration(name: name, isLet: isLet, value: lowerExpression(value, stateVars))
        case .ifStatement(let condition, let thenBranch, let elseBranch):
            return .ifStatement(
                condition: lowerExpression(condition, stateVars),
                thenBranch: thenBranch.map { lowerStatement($0, stateVars) },
                elseBranch: elseBranch?.map { lowerStatement($0, stateVars) })
        case .functionDeclaration(let name, let parameters, let body):
            return .functionDeclaration(name: name, parameters: parameters, body: lowerBody(body, stateVars))
        case .returnStatement(let value?):
            return .returnStatement(lowerExpression(value, stateVars))
        case .forLoop(let variable, let sequence, let body):
            return .forLoop(variable: variable, sequence: lowerExpression(sequence, stateVars),
                            body: body.map { lowerStatement($0, stateVars) })
        default:
            return statement
        }
    }

    // MARK: - Expressions

    private func lowerExpression(_ expr: IRExpression, _ stateVars: Set<String>) -> IRExpression {
        let lower = { (e: IRExpression) in self.lowerExpression(e, stateVars) }
        switch expr {
        case .assignment(let target, let value):
            if let path = statePath(target, stateVars) {
                return write(path, stateVars) { _ in lower(value) }
            }
            return .assignment(target: target, value: lower(value))

        case .augmentedAssignment(let target, let op, let value):
            if let path = statePath(target, stateVars) {
                return write(path, stateVars) { .binary(lhs: $0, op: Self.binary(op), rhs: lower(value)) }
            }
            return .augmentedAssignment(target: target, op: op, value: lower(value))

        case .functionCall(.memberAccess(let base, let method, let kind), let args) where Self.isValueAccess(kind):
            if let path = statePath(base, stateVars), let newValue = mutation(method, args.map {
                IRArgument(label: $0.label, value: lower($0.value))
            }) {
                return write(path, stateVars, newValue)
            }
            return .functionCall(callee: .memberAccess(base: lower(base), member: method, kind: kind),
                                 arguments: args.map { IRArgument(label: $0.label, value: lower($0.value)) })

        case .functionCall(let callee, let args):
            return .functionCall(callee: lower(callee), arguments: args.map { IRArgument(label: $0.label, value: lower($0.value)) })
        case .binary(let lhs, let op, let rhs):
            return .binary(lhs: lower(lhs), op: op, rhs: lower(rhs))
        case .unary(let op, let inner):
            return .unary(op: op, expr: lower(inner))
        case .ternary(let condition, let thenExpr, let elseExpr):
            return .ternary(condition: lower(condition), thenExpr: lower(thenExpr), elseExpr: lower(elseExpr))
        case .memberAccess(let base, let member, let kind):
            return .memberAccess(base: lower(base), member: member, kind: kind)
        case .subscript(let base, let index):
            return .subscript(base: lower(base), index: lower(index))
        case .array(let elements):
            return .array(elements.map(lower))
        case .closure(let closure):
            return .closure(IRClosureExpression(parameters: closure.parameters, body: lowerBody(closure.body, stateVars)))
        case .interpolatedString(let parts):
            return .interpolatedString(parts.map {
                if case .expression(let e) = $0 { return .expression(lower(e)) }
                return $0
            })
        case .view(let viewNode):
            lowerView(viewNode, stateVars)
            return .view(viewNode)
        default:
            return expr
        }
    }

    // MARK: - Writes

    private enum Step {
        case member(String)
        case index(IRExpression)
    }

    /// `todos[i].done` -> ("todos", [.index(i), .member("done")]) when the root is @State.
    private func statePath(_ expr: IRExpression, _ stateVars: Set<String>) -> (root: String, steps: [Step])? {
        switch expr {
        case .identifier(let name):
            return stateVars.contains(name) ? (name, []) : nil
        case .memberAccess(let base, let member, let kind) where Self.isValueAccess(kind):
            return statePath(base, stateVars).map { ($0.root, $0.steps + [.member(member)]) }
        case .subscript(let base, let index):
            return statePath(base, stateVars).map { ($0.root, $0.steps + [.index(lowerExpression(index, stateVars))]) }
        default:
            return nil
        }
    }

    /// `setRoot(newRoot)`, as a functional update `setRoot((root) => …)` when the new value
    /// depends on the current one, so consecutive writes in one action compose like Swift.
    private func write(_ path: (root: String, steps: [Step]), _ stateVars: Set<String>,
                       _ newLeaf: (IRExpression) -> IRExpression) -> IRExpression {
        let root = path.root
        let newRoot = rebuild(.identifier(root), path.steps[...], newLeaf)
        let setter = IRExpression.identifier("set" + root.prefix(1).uppercased() + root.dropFirst())
        let usesCurrent = !path.steps.isEmpty || references(newRoot, root)
        let argument = usesCurrent
            ? IRExpression.closure(IRClosureExpression(parameters: [IRClosureParameter(name: root)], body: [.expression(newRoot)]))
            : newRoot
        return .functionCall(callee: setter, arguments: [IRArgument(value: argument)])
    }

    /// Immutable copy of `current` with the value at `steps` replaced by `newLeaf(old value)`.
    private func rebuild(_ current: IRExpression, _ steps: ArraySlice<Step>,
                         _ newLeaf: (IRExpression) -> IRExpression) -> IRExpression {
        guard let step = steps.first else { return newLeaf(current) }
        switch step {
        case .member(let name):
            // { ...current, name: … }
            let child = rebuild(.memberAccess(base: current, member: name, kind: .instance), steps.dropFirst(), newLeaf)
            return .objectSpread(base: current, overrides: [(name, child)])
        case .index(let index):
            // current.map((_item, _index) => _index === index ? … : _item)
            let child = rebuild(.identifier("_item"), steps.dropFirst(), newLeaf)
            let body = IRExpression.ternary(
                condition: .binary(lhs: .identifier("_index"), op: .equals, rhs: index),
                thenExpr: child, elseExpr: .identifier("_item"))
            return call(current, "map", .closure(IRClosureExpression(
                parameters: [IRClosureParameter(name: "_item"), IRClosureParameter(name: "_index")],
                body: [.expression(body)])))
        }
    }

    /// New value for Swift's mutating collection/Bool methods, or nil for anything else.
    private func mutation(_ method: String, _ args: [IRArgument]) -> ((IRExpression) -> IRExpression)? {
        let labels = args.map { $0.label }
        switch (method, labels) {
        case ("toggle", []):
            return { .unary(op: .not, expr: $0) }
        case ("append", [nil]):
            return { self.call($0, "concat", .array([args[0].value])) }
        case ("append", ["contentsOf"]):
            return { self.call($0, "concat", args[0].value) }
        case ("insert", [nil, "at"]):
            // current.slice(0, i).concat([x], current.slice(i))
            return { current in
                .functionCall(
                    callee: .memberAccess(base: self.call(current, "slice", .numberLiteral(0), args[1].value), member: "concat", kind: .instance),
                    arguments: [IRArgument(value: .array([args[0].value])), IRArgument(value: self.call(current, "slice", args[1].value))])
            }
        case ("remove", ["at"]):
            // current.filter((_item, _index) => _index !== i)
            return { self.call($0, "filter", .closure(IRClosureExpression(
                parameters: [IRClosureParameter(name: "_item"), IRClosureParameter(name: "_index")],
                body: [.expression(.binary(lhs: .identifier("_index"), op: .notEquals, rhs: args[0].value))]))) }
        case ("removeAll", []):
            return { _ in .array([]) }
        case ("removeAll", ["where"]), ("removeAll", [nil]):
            // current.filter((x) => !(predicate))
            guard case .closure(let predicate) = args[0].value, predicate.body.count == 1,
                  case .expression(let test) = predicate.body[0] else { return nil }
            return { self.call($0, "filter", .closure(IRClosureExpression(
                parameters: predicate.parameters, body: [.expression(.unary(op: .not, expr: test))]))) }
        default:
            return nil
        }
    }

    private func call(_ base: IRExpression, _ method: String, _ args: IRExpression...) -> IRExpression {
        .functionCall(callee: .memberAccess(base: base, member: method, kind: .instance),
                      arguments: args.map { IRArgument(value: $0) })
    }

    // MARK: - Analysis

    /// State variables read and written by a statement. Reading a variable inside its own
    /// write (`count = count + 1`) is part of that write, not a separate read.
    private func collect(_ statement: IRStatement, _ stateVars: Set<String>,
                         reads: inout Set<String>, writes: inout Set<String>) {
        switch statement {
        case .expression(let expr), .returnStatement(let expr?), .variableDeclaration(_, _, let expr):
            collect(expr, stateVars, reads: &reads, writes: &writes)
        case .ifStatement(let condition, let thenBranch, let elseBranch):
            collect(condition, stateVars, reads: &reads, writes: &writes)
            (thenBranch + (elseBranch ?? [])).forEach { collect($0, stateVars, reads: &reads, writes: &writes) }
        default:
            break
        }
    }

    private func collect(_ expr: IRExpression, _ stateVars: Set<String>,
                         reads: inout Set<String>, writes: inout Set<String>) {
        var target: IRExpression?
        var parts: [IRExpression] = []
        switch expr {
        case .assignment(let t, let value), .augmentedAssignment(let t, _, let value):
            target = t; parts = [value]
        case .functionCall(.memberAccess(let base, let method, let kind), let args)
            where Self.isValueAccess(kind) && statePath(base, stateVars) != nil && mutation(method, args) != nil:
            target = base; parts = args.map(\.value)
        default:
            stateVars.filter { references(expr, $0) }.forEach { reads.insert($0) }
            return
        }
        guard let target, let root = statePath(target, stateVars)?.root else {
            stateVars.filter { references(expr, $0) }.forEach { reads.insert($0) }
            return
        }
        writes.insert(root)
        for part in parts {
            stateVars.filter { $0 != root && references(part, $0) }.forEach { reads.insert($0) }
        }
    }

    /// Whether `expr` mentions the identifier `name` (closures that rebind it excluded).
    private func references(_ expr: IRExpression, _ name: String) -> Bool {
        let check = { (e: IRExpression) in self.references(e, name) }
        switch expr {
        case .identifier(let n): return n == name
        case .binary(let l, _, let r): return check(l) || check(r)
        case .unary(_, let e): return check(e)
        case .ternary(let c, let t, let e): return check(c) || check(t) || check(e)
        case .memberAccess(let b, _, _): return check(b)
        case .subscript(let b, let i): return check(b) || check(i)
        case .functionCall(let c, let args): return check(c) || args.contains { check($0.value) }
        case .assignment(let t, let v), .augmentedAssignment(let t, _, let v): return check(t) || check(v)
        case .array(let es): return es.contains(where: check)
        case .objectSpread(let b, let o): return check(b) || o.contains { check($0.1) }
        case .interpolatedString(let parts):
            return parts.contains { if case .expression(let e) = $0 { return check(e) }; return false }
        case .closure(let c):
            if c.parameters.contains(where: { $0.name == name }) { return false }
            return c.body.contains {
                var r: Set<String> = [], w: Set<String> = []
                collect($0, [name], reads: &r, writes: &w)
                return !r.isEmpty || !w.isEmpty
            }
        default: return false
        }
    }

    /// `value.member` (instance or not yet classified), as opposed to `.case` or `Type.member`.
    private static func isValueAccess(_ kind: IRMemberAccessKind) -> Bool {
        kind == .instance || kind == .unknown
    }

    private static func binary(_ op: IRAugmentedAssignmentOperator) -> IRBinaryOperator {
        switch op {
        case .addAssign: return .add
        case .subtractAssign: return .subtract
        case .multiplyAssign: return .multiply
        case .divideAssign: return .divide
        case .moduloAssign: return .modulo
        }
    }
}
