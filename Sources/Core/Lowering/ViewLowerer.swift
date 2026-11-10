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
        // Validate runtime capabilities
        let isRuntimeView = context.componentRegistry.definition(for: componentName)?.kind == .runtimeView
        let isSupported = context.capabilityRegistry.supportsComponent(componentName)
        
        if isRuntimeView && !isSupported {
            context.addDiagnostic("not yet supported: view \(componentName)", at: callExpr)
        } else {
            context.markComponentUsed(componentName)
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
            properties.append(IRProperty(name: propName, value: value))
        }
        
        var children: [IRViewNode] = []
        var statements: [IRStatement] = []

        // Handle trailing closure
        if let trailingClosure = callExpr.trailingClosure {
            for item in trailingClosure.statements {
                if let stmtLowerer = stmtLowerer {
                    let irStmt = stmtLowerer.lowerCodeBlockItem(item)
                    
                    // If the statement is just a view expression, add it as a child
                    if case .expression(let expr) = irStmt, 
                       let childView = lowerIRExpressionToView(expr) {
                        children.append(childView)
                    } else if componentName == "Button" {
                        statements.append(irStmt)  // Button's closure is its action
                    } else {
                        // A view builder closure only holds views; `if`, `let` etc. need dedicated lowering.
                        let isIf = item.item.as(ExpressionStmtSyntax.self)?.expression.is(IfExprSyntax.self) ?? false
                        let what = isIf ? "if" : "\(item.item.kind)"
                        context.addDiagnostic("not yet supported: \(what) in \(componentName) content", at: item)
                    }
                }
            }
        }
        
        if componentName == "Toggle" {
            return lowerToggle(properties, callExpr: callExpr)
        }

        return IRViewNode(
            componentName: componentName,
            properties: properties,
            modifiers: [],
            children: children,
            statements: statements
        )
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
