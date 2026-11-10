import Foundation
import SwiftSyntax

/// Converts SwiftUI view syntax to semantic IR view nodes
public class ViewLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer
    private let modifierLowerer: ModifierLowerer
    
    private var stmtLowerer: StatementLowerer?
    
    public init(context: LoweringContext, exprLowerer: ExpressionLowerer, modifierLowerer: ModifierLowerer) {
        self.context = context
        self.exprLowerer = exprLowerer
        self.modifierLowerer = modifierLowerer
    }
    
    public func setStatementLowerer(_ stmtLowerer: StatementLowerer) {
        self.stmtLowerer = stmtLowerer
    }
    
    public func lowerViewCall(_ callExpr: FunctionCallExprSyntax) -> IRViewNode? {
        guard let componentName = extractComponentName(callExpr.calledExpression) else {
            return nil
        }
        
        // Ensure it's a registered component (either runtime or custom)
        guard context.componentRegistry.isComponent(componentName) else {
            return nil
        }
        if componentName == "ForEach" {
            return lowerForEach(callExpr)
        }
        // Validate runtime capabilities
        let isRuntimeView = context.componentRegistry.definition(for: componentName)?.kind == .runtimeView
        let isSupported = context.capabilityRegistry.supportsComponent(componentName)
        
        if isRuntimeView && !isSupported {
            context.addDiagnostic("not yet supported: view \(componentName)", at: callExpr)
        } else if isRuntimeView {
            context.markComponentUsed(componentName)  // imported from @swiftuijs/ui
        }

        if let props = context.viewProps[componentName] {
            return lowerCustomViewCall(callExpr, componentName: componentName, props: props)
        }

        var properties: [IRProperty] = []
        for (index, arg) in callExpr.arguments.enumerated() {
            let propName: String
            if let label = arg.label {
                propName = label.text
            } else {
                // Map positional arguments to properties
                switch componentName {
                case "Text": propName = "content"
                case "Button" where index == 0: propName = "title"
                case "TextField" where index == 0, "SecureField" where index == 0: propName = "placeholder"
                case "Toggle" where index == 0: propName = "label"
                default: propName = "arg\(index)"
                }
            }

            // Validate property (an unsupported view is already reported as a whole)
            if !(isRuntimeView && !isSupported),
               !context.capabilityRegistry.supportsProperty(propName, on: componentName) {
                let argument = arg.label.map { "argument '\($0.text):'" } ?? "unlabeled argument \(index + 1)"
                context.addDiagnostic("not yet supported: \(componentName) \(argument)", at: arg)
            }

            // Two-way bindings: $state -> value + onChange calling the React setter
            if Self.bindingProperty[componentName] == propName {
                properties += lowerBinding(arg.expression, for: componentName)
                continue
            }

            var value = exprLowerer.lower(arg.expression)
            if propName == "alignment" {
                // SwiftUI .topLeading -> @swiftuijs/ui "top-leading"
                if let member = arg.expression.as(MemberAccessExprSyntax.self), member.base == nil,
                   let alignment = Self.alignments[member.declName.baseName.text],
                   // @swiftuijs/ui 0.1.4 ZStack (CSS grid) ignores horizontal alignment.
                   !(componentName == "ZStack" && (alignment.contains("leading") || alignment.contains("trailing"))) {
                    value = .stringLiteral(alignment)
                } else {
                    context.addDiagnostic(
                        "not yet supported: alignment \(arg.expression.trimmedDescription)", at: arg.expression)
                }
            }
            // Button(action: { … }) -> onClick
            let emittedName = componentName == "Button" && propName == "action" ? "onClick" : propName
            properties.append(IRProperty(name: emittedName, value: value))
        }
        
        var children: [IRViewNode] = []
        var statements: [IRStatement] = []

        // Handle trailing closure
        if let trailingClosure = callExpr.trailingClosure, let stmtLowerer {
            let hasAction = callExpr.arguments.contains { $0.label?.text == "action" }
            if componentName == "Button" && !hasAction {
                // Button("Title") { action }: the closure is its action
                statements = trailingClosure.statements.map { stmtLowerer.lowerCodeBlockItem($0) }
            } else {
                children = lowerViewContent(trailingClosure.statements, in: componentName)
            }
        }
        
        if componentName == "Toggle" {
            return lowerToggle(properties, callExpr: callExpr)
        }
        if componentName == "NavigationStack" {
            return lowerNavigationStack(children)
        }
        if componentName == "List" {
            // SwiftUI's List takes all the width offered, even inside a leading-aligned stack
            let fill = IRModifier(name: "frame", arguments: [])
            fill.effects = [.style(key: "alignSelf", value: .stringLiteral("stretch"))]
            return IRViewNode(componentName: "List", properties: properties, modifiers: [fill], children: children)
        }

        return IRViewNode(
            componentName: componentName,
            properties: properties,
            modifiers: [],
            children: children,
            statements: statements
        )
    }

    /// The views in a view builder body (a container's closure or an `if` branch).
    /// Supports view expressions and `if`/`else`; anything else is reported.
    func lowerViewContent(_ items: CodeBlockItemListSyntax, in container: String) -> [IRViewNode] {
        items.compactMap { item -> IRViewNode? in
            let expr = item.item.as(ExprSyntax.self) ?? item.item.as(ExpressionStmtSyntax.self)?.expression
            if let ifExpr = expr?.as(IfExprSyntax.self) {
                return lowerViewIf(ifExpr, in: container)
            }
            if let expr, let view = lowerViewExpression(expr) {
                return view
            }
            context.addDiagnostic("not yet supported: \(item.item.kind) in \(container) content", at: item)
            return nil
        }
    }

    /// `ForEach(items)` (Identifiable: key `item.id`), `ForEach(items, id: \.self | \.name)`
    /// or `ForEach(0..<n)`, with one view (or an `if` of single views) per item.
    private func lowerForEach(_ callExpr: FunctionCallExprSyntax) -> IRViewNode? {
        let args = Array(callExpr.arguments)
        guard let first = args.first, first.label == nil, args.count <= 2,
              let closure = callExpr.trailingClosure, callExpr.additionalTrailingClosures.isEmpty else {
            context.addDiagnostic("not yet supported: ForEach form", at: callExpr)
            return nil
        }
        guard let parameter = forEachParameter(closure) else {
            context.addDiagnostic("not yet supported: ForEach closure without a named parameter", at: closure)
            return nil
        }

        // Data and key
        var data: IRExpression
        var key: IRExpression = .memberAccess(base: .identifier(parameter), member: "id", kind: .instance)
        if let range = first.expression.as(InfixOperatorExprSyntax.self),
           range.operator.as(BinaryOperatorExprSyntax.self)?.operator.text == "..<",
           range.leftOperand.as(IntegerLiteralExprSyntax.self)?.literal.text == "0" {
            // 0..<n -> Array.from({ length: n }, (_, i) => i)
            data = .functionCall(callee: .identifier("Array.from"), arguments: [
                IRArgument(value: .dictionary([("length", exprLowerer.lower(range.rightOperand))])),
                IRArgument(value: .closure(IRClosureExpression(
                    parameters: [IRClosureParameter(name: "_"), IRClosureParameter(name: "i")],
                    body: [.expression(.identifier("i"))]))),
            ])
            key = .identifier(parameter)
        } else {
            data = exprLowerer.lower(first.expression)
        }
        if args.count == 2 {
            guard args[1].label?.text == "id", let keyPath = args[1].expression.as(KeyPathExprSyntax.self),
                  keyPath.root == nil, keyPath.components.count == 1,
                  let property = keyPath.components.first?.component.as(KeyPathPropertyComponentSyntax.self) else {
                context.addDiagnostic("not yet supported: ForEach id \(args[1].trimmedDescription)", at: args[1])
                return nil
            }
            let name = property.declName.baseName.text
            key = name == "self" ? .identifier(parameter) : .memberAccess(base: .identifier(parameter), member: name, kind: .instance)
        }

        // One view per item, keyed for React
        let views = lowerViewContent(closure.statements, in: "ForEach")
        guard views.count == 1, let content = views.first, addKey(key, to: content) else {
            context.addDiagnostic("not yet supported: ForEach item with several views", at: closure)
            return nil
        }
        return IRForEachViewNode(data: data, parameter: parameter, content: content)
    }

    private func forEachParameter(_ closure: ClosureExprSyntax) -> String? {
        guard let clause = closure.signature?.parameterClause else { return nil }
        if let shorthand = clause.as(ClosureShorthandParameterListSyntax.self), shorthand.count == 1 {
            return shorthand.first?.name.text
        }
        if let parameters = clause.as(ClosureParameterClauseSyntax.self), parameters.parameters.count == 1,
           parameters.parameters.first?.type == nil {
            return parameters.parameters.first?.firstName.text
        }
        return nil
    }

    /// Puts `key` on the element each item renders (on every branch of a conditional).
    private func addKey(_ key: IRExpression, to view: IRViewNode) -> Bool {
        if let conditional = view as? IRConditionalViewNode {
            let branches = [conditional.thenViews] + (conditional.elseViews.map { [$0] } ?? [])
            return branches.allSatisfy { $0.count <= 1 && $0.allSatisfy { addKey(key, to: $0) } }
        }
        if view is IRForEachViewNode { return false }
        view.properties.insert(IRProperty(name: "key", value: key), at: 0)
        return true
    }

    /// `if cond { A } else if other { B } else { C }` -> nested conditional view nodes.
    private func lowerViewIf(_ ifExpr: IfExprSyntax, in container: String) -> IRViewNode? {
        guard let stmtLowerer else { return nil }
        let condition = stmtLowerer.lowerConditionList(ifExpr.conditions)
        let thenViews = lowerViewContent(ifExpr.body.statements, in: container)
        var elseViews: [IRViewNode]?
        if let elseIf = ifExpr.elseBody?.as(IfExprSyntax.self) {
            elseViews = lowerViewIf(elseIf, in: container).map { [$0] }
        } else if let elseBlock = ifExpr.elseBody?.as(CodeBlockSyntax.self) {
            elseViews = lowerViewContent(elseBlock.statements, in: container)
        }
        return IRConditionalViewNode(condition: condition, thenViews: thenViews, elseViews: elseViews)
    }

    /// `Row(title: "x") { action() }` for a View declared in this file. Labels must name its
    /// props (Swift's memberwise init); a trailing closure fills the last function-typed prop.
    private func lowerCustomViewCall(_ callExpr: FunctionCallExprSyntax, componentName: String,
                                     props: [IRClosureParameter]) -> IRViewNode {
        var remaining = props
        var properties: [IRProperty] = []
        for arg in callExpr.arguments {
            guard let label = arg.label?.text, let index = remaining.firstIndex(where: { $0.name == label }) else {
                context.addDiagnostic("not yet supported: \(componentName) argument \(arg.trimmedDescription)", at: arg)
                continue
            }
            properties.append(IRProperty(name: label, value: exprLowerer.lower(arg.expression)))
            remaining.remove(at: index)
        }
        if let closure = callExpr.trailingClosure {
            if let prop = remaining.last(where: { $0.type == "() => void" }) {
                properties.append(IRProperty(name: prop.name, value: exprLowerer.lower(ExprSyntax(closure))))
            } else {
                context.addDiagnostic("not yet supported: trailing closure for \(componentName)", at: closure)
            }
        }
        if !callExpr.additionalTrailingClosures.isEmpty {
            context.addDiagnostic("not yet supported: multiple trailing closures", at: callExpr.additionalTrailingClosures)
        }
        return IRViewNode(componentName: componentName, properties: properties, modifiers: [], children: [], statements: [])
    }

    /// NavigationStack { content.navigationTitle("T") } -> NavigationStack (full window height)
    /// > StandardPage(navigationTitle: "T") > content, the swiftuijs page structure.
    private func lowerNavigationStack(_ children: [IRViewNode]) -> IRViewNode {
        var pageProperties = [IRProperty(name: "id", value: .stringLiteral("root"))]
        for child in children {
            for modifier in child.modifiers {
                if let index = modifier.effects.firstIndex(where: {
                    if case .attribute("navigationTitle", _) = $0 { return true }
                    return false
                }), case .attribute(_, let title) = modifier.effects[index] {
                    modifier.effects.remove(at: index)
                    pageProperties.append(IRProperty(name: "navigationTitle", value: title))
                }
            }
        }
        context.markComponentUsed("StandardPage")
        let page = IRViewNode(componentName: "StandardPage", properties: pageProperties, children: children)
        let fullHeight = IRModifier(name: "frame", arguments: [])
        fullHeight.effects = [.style(key: "height", value: .stringLiteral("100dvh"))]
        return IRViewNode(componentName: "NavigationStack", modifiers: [fullHeight], children: [page])
    }

    /// The SwiftUI argument that takes a Binding, per component.
    private static let bindingProperty = ["TextField": "text", "SecureField": "text", "Toggle": "isOn"]

    /// `$name` of a @State variable -> swiftuijs value/onChange props. Other bindings are reported.
    private func lowerBinding(_ expr: ExprSyntax, for component: String) -> [IRProperty] {
        guard let ref = expr.as(DeclReferenceExprSyntax.self), ref.baseName.text.hasPrefix("$"),
              let symbol = context.lookupVariable(String(ref.baseName.text.dropFirst())),
              symbol.kind == .stateVariable else {
            context.addDiagnostic("not yet supported: binding \(expr.trimmedDescription)", at: expr)
            return []
        }
        let name = symbol.name
        let setter = IRExpression.identifier("set" + name.prefix(1).uppercased() + name.dropFirst())

        if component == "Toggle" {
            // swiftuijs Toggle: onChange(value: boolean)
            return [IRProperty(name: "isOn", value: .identifier(name)), IRProperty(name: "onChange", value: setter)]
        }
        // swiftuijs TextField/SecureField: onChange(event) -> setter(event.target.value)
        let newValue = IRExpression.memberAccess(
            base: .memberAccess(base: .identifier("e"), member: "target", kind: .instance),
            member: "value", kind: .instance)
        let handler = IRExpression.closure(IRClosureExpression(
            parameters: [IRClosureParameter(name: "e")],
            body: [.expression(.functionCall(callee: setter, arguments: [IRArgument(value: newValue)]))]))
        return [IRProperty(name: "value", value: .identifier(name)), IRProperty(name: "onChange", value: handler)]
    }

    /// SwiftUI `Toggle("Label", isOn:)` shows the label leading and the switch trailing; swiftuijs
    /// Toggle has no label, so emit HStack { Text(label) Spacer() Toggle(aria-label:) }.
    private func lowerToggle(_ properties: [IRProperty], callExpr: FunctionCallExprSyntax) -> IRViewNode {
        if let closure = callExpr.trailingClosure {
            context.addDiagnostic("not yet supported: Toggle with a label closure", at: closure)
        }
        guard let label = properties.first(where: { $0.name == "label" })?.value else {
            return IRViewNode(componentName: "Toggle", properties: properties, modifiers: [], children: [], statements: [])
        }
        for name in ["HStack", "Text", "Spacer"] { context.markComponentUsed(name) }
        let toggle = IRViewNode(
            componentName: "Toggle",
            properties: [IRProperty(name: "aria-label", value: label)] + properties.filter { $0.name != "label" },
            modifiers: [], children: [], statements: [])
        return IRViewNode(
            componentName: "HStack",
            properties: [IRProperty(name: "alignment", value: .stringLiteral("center"))],
            modifiers: [],
            children: [
                IRViewNode(componentName: "Text", properties: [IRProperty(name: "content", value: label)],
                           modifiers: [], children: [], statements: []),
                IRViewNode(componentName: "Spacer", properties: [], modifiers: [], children: [], statements: []),
                toggle,
            ],
            statements: [])
    }
    
    private func lowerIRExpressionToView(_ expr: IRExpression) -> IRViewNode? {
        if case .view(let node) = expr {
            return node
        }
        return nil
    }
    
    public func lowerViewExpression(_ exprSyntax: ExprSyntaxProtocol) -> IRViewNode? {
        var baseExpr = exprSyntax
        var modifierStack: [FunctionCallExprSyntax] = []
        
        while let funcCall = baseExpr.as(FunctionCallExprSyntax.self) {
            modifierStack.append(funcCall)
            
            if let nextBase = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
               let base = nextBase.base {
                baseExpr = base
            } else {
                break
            }
        }
        
        guard let baseViewCall = baseExpr.as(FunctionCallExprSyntax.self) else {
            return nil
        }
        
        guard let viewNode = lowerViewCall(baseViewCall) else {
            return nil
        }
        
        // All modifiers become one style object, which matches SwiftUI only when they run in
        // box order (padding, frame, background, cornerRadius) and set each property once.
        var styledKeys: Set<String> = []
        var lastRank = 0
        for i in stride(from: modifierStack.count - 1, through: 0, by: -1) {
            let modifierCall = modifierStack[i]
            
            if let modifier = modifierLowerer.lower(modifierCall) {
                let keys = Set(modifier.effects.compactMap { effect -> String? in
                    if case .style(let key, _) = effect { return key }
                    return nil
                })
                let rank = Self.boxOrder[modifier.name] ?? lastRank
                if rank < lastRank || !styledKeys.isDisjoint(with: keys) {
                    let anchor = modifierCall.calledExpression.as(MemberAccessExprSyntax.self)?.period
                    context.addDiagnostic(
                        "not yet supported: .\(modifier.name) in this position (SwiftUI modifier order)",
                        at: anchor.map(Syntax.init) ?? Syntax(modifierCall))
                }
                styledKeys.formUnion(keys)
                lastRank = max(lastRank, rank)
                if modifier.name == "disabled", !["Button", "TextField", "SecureField", "Toggle"].contains(viewNode.componentName) {
                    // swiftuijs controls take `disabled`; SwiftUI disabling a whole container has no single prop
                    context.addDiagnostic("not yet supported: .disabled on \(viewNode.componentName.isEmpty ? "this view" : viewNode.componentName)", at: modifierCall)
                }
                viewNode.applyModifier(modifier)
            }
        }
        
        return viewNode
    }
    
    /// Order in which box modifiers flatten correctly onto one element.
    private static let boxOrder: [String: Int] = ["padding": 1, "frame": 2, "background": 3, "cornerRadius": 4]

    /// SwiftUI Alignment / HorizontalAlignment / VerticalAlignment -> @swiftuijs/ui EAlignment.
    private static let alignments: [String: String] = [
        "leading": "leading", "center": "center", "trailing": "trailing",
        "top": "top", "bottom": "bottom",
        "topLeading": "top-leading", "topTrailing": "top-trailing",
        "bottomLeading": "bottom-leading", "bottomTrailing": "bottom-trailing",
    ]

    private func extractComponentName(_ exprSyntax: ExprSyntaxProtocol) -> String? {
        if let ident = exprSyntax.as(DeclReferenceExprSyntax.self) {
            return ident.baseName.text
        }
        
        if let member = exprSyntax.as(MemberAccessExprSyntax.self) {
            return member.declName.baseName.text
        }
        
        return nil
    }
}
