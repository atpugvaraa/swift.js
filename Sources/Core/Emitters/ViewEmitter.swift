import Foundation

/// Emits JSX view elements from IR view nodes
public final class ViewEmitter {
    private let exprEngine: ExpressionEmissionEngine
    private let styleEmitter: ReactStyleEmitter
    private let statementEmitter: StatementEmitter?
    
    public init(
        exprEngine: ExpressionEmissionEngine = ExpressionEmissionEngine(),
        statementEmitter: StatementEmitter? = nil
    ) {
        self.exprEngine = exprEngine
        self.styleEmitter = ReactStyleEmitter(exprEngine: exprEngine)
        self.statementEmitter = statementEmitter
    }
    
    public func emit(_ view: IRViewNode) -> String {
        if let conditional = view as? IRConditionalViewNode {
            return emitConditional(conditional)
        }
        if let forEach = view as? IRForEachViewNode {
            let data = exprEngine.emit(forEach.data, context: IRExpressionContext(precedence: 18))
            return "{\(data).map((\(forEach.parameter)) => \(emitAsExpression(forEach.content)))}"
        }
        var attributes: [String] = []
        var bodyParts: [String] = []
        var wrapperHandlers: [String] = []  // tap handlers, on a layout-neutral wrapper

        // 1. Process Properties (e.g., content, label)
        for property in view.properties {
            let value = exprEngine.emit(property.value, context: IRExpressionContext(isProperty: true))
            // @swiftuijs/ui takes Text content and Button titles as JSX children.
            if Self.isChildLabel(property.name, on: view.componentName) {
                bodyParts.append("{\(value)}")
            } else {
                attributes.append("\(property.name)={\(value)}")
            }
        }
        // SwiftUI stacks centre their content by default; @swiftuijs/ui stacks don't.
        if ["VStack", "HStack"].contains(view.componentName),
           !view.properties.contains(where: { $0.name == "alignment" }) {
            attributes.append("alignment={\"center\"}")
        }
        
        // 2. Process Modifiers
        var styles: [IRModifierEffect] = []
        for modifier in view.modifiers {
            for effect in modifier.effects {
                switch effect {
                case .interaction(let event, let handler):
                    // swiftuijs views mostly don't take DOM event props, so attach the handler to a
                    // `display: contents` wrapper: no box of its own, children's clicks bubble to it.
                    wrapperHandlers.append("\(mapEventToReact(event))={\(exprEngine.emit(handler))}")
                case .animation(let value):
                    attributes.append("animation={\(exprEngine.emit(value))}")
                case .font(let value):
                    styles.append(.font(value))
                case .style(let key, let value):
                    styles.append(.style(key: key, value: value))
                case .spacing, .foregroundColor, .background, .opacity, .frame, .alignment, .offset:
                    styles.append(effect)
                case .attribute(let name, let value):
                    attributes.append("\(name)={\(exprEngine.emit(value))}")
                case .custom(let name, let args):
                    let argStr = args.map { exprEngine.emit($0) }.joined(separator: ", ")
                    attributes.append("data-\(name)={\(argStr)}")
                }
            }
        }
        
        // 3. Emit Style Object
        let styleObj = styleEmitter.emitStyleObject(from: styles)
        if !styleObj.isEmpty {
            attributes.append("style={\(styleObj)}")
        }
        
        // 4. Generate JSX
        let tag = view.componentName

        for child in view.children {
            bodyParts.append(emit(child))
        }
        
        var actionStatements: [IRStatement] = []
        for stmt in view.statements {
            actionStatements.append(stmt)
        }
        
        if tag == "Button" && !actionStatements.isEmpty {
            let actionCode = actionStatements.map { statementEmitter?.emit($0) ?? "/* statement */" }.joined(separator: "\n")
            attributes.append("onClick={() => {\n\(actionCode)\n}}")
        } else {
            for stmt in actionStatements {
                if let emitter = statementEmitter {
                    bodyParts.append(emitter.emit(stmt))
                } else {
                    bodyParts.append("/* statement */")
                }
            }
        }
        
        let attrStr = attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")
        
        let element = bodyParts.isEmpty
            ? "<\(tag)\(attrStr) />"
            : "<\(tag)\(attrStr)>\n\(bodyParts.joined(separator: "\n"))\n</\(tag)>"
        guard !wrapperHandlers.isEmpty else { return element }
        // A ForEach key must stay on the outermost element.
        let key = view.properties.first { $0.name == "key" }.map { " key={\(exprEngine.emit($0.value))}" } ?? ""
        return "<div\(key) style={{ display: \"contents\" }} \(wrapperHandlers.joined(separator: " "))>\n\(element)\n</div>"
    }
    
    /// `{cond ? <A /> : <B />}`, or `{cond && <A />}` without else; several views use a fragment.
    private func emitConditional(_ node: IRConditionalViewNode) -> String {
        let condition = exprEngine.emit(node.condition, context: IRExpressionContext(precedence: 3))
        let thenJSX = jsx(node.thenViews)
        guard let elseViews = node.elseViews else {
            return "{\(condition) && \(thenJSX)}"
        }
        return "{\(condition) ? \(thenJSX) : \(jsx(elseViews))}"
    }

    private func jsx(_ views: [IRViewNode]) -> String {
        switch views.count {
        case 0: return "null"
        case 1: return emitAsExpression(views[0])
        default: return "<>\n\(views.map(emit).joined(separator: "\n"))\n</>"
        }
    }

    /// A conditional nested directly in a branch must not add another pair of braces.
    private func emitAsExpression(_ view: IRViewNode) -> String {
        let emitted = emit(view)
        if view is IRConditionalViewNode { return String(emitted.dropFirst().dropLast()) }
        return emitted
    }

    private static func isChildLabel(_ property: String, on component: String) -> Bool {
        (component == "Text" && property == "content") || (component == "Button" && property == "title")
    }

    private func mapEventToReact(_ event: String) -> String {
        switch event {
        case "onTap": return "onClick"
        case "onHover": return "onMouseEnter"
        default: return event
        }
    }
}
