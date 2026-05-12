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
        var attributes: [String] = []
        
        // 1. Process Properties (e.g., content, label)
        for property in view.properties {
            let value = exprEngine.emit(property.value, context: IRExpressionContext(isProperty: true))
            attributes.append("\(property.name)={\(value)}")
        }
        
        // 2. Process Modifiers
        var styles: [IRModifierEffect] = []
        for modifier in view.modifiers {
            for effect in modifier.effects {
                switch effect {
                case .interaction(let event, let handler):
                    let reactEvent = mapEventToReact(event)
                    attributes.append("\(reactEvent)={\(exprEngine.emit(handler))}")
                case .animation(let value):
                    attributes.append("animation={\(exprEngine.emit(value))}")
                case .font(let value):
                    styles.append(.font(value))
                case .style(let key, let value):
                    styles.append(.style(key: key, value: value))
                case .spacing, .foregroundColor, .background, .opacity, .frame, .alignment, .offset:
                    styles.append(effect)
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
        
        var bodyParts: [String] = []
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
        
        if bodyParts.isEmpty {
            return "<\(tag)\(attrStr) />"
        }
        
        return "<\(tag)\(attrStr)>\n\(bodyParts.joined(separator: "\n"))\n</\(tag)>"
    }
    
    private func mapEventToReact(_ event: String) -> String {
        switch event {
        case "onTap": return "onClick"
        case "onHover": return "onMouseEnter"
        default: return event
        }
    }
}
