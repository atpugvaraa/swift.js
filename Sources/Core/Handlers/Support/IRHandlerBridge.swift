import Foundation
import SwiftSyntax

/// Bridges legacy handlers to the new IR lowering and emitter pipeline.
/// Handlers can use this while the visitor still expects string output.
public final class IRHandlerBridge {
    public nonisolated(unsafe) static let shared = IRHandlerBridge()
    
    private let loweringContext = LoweringContext()
    private let expressionLowerer: ExpressionLowerer
    private let exprEngine: ExpressionEmissionEngine
    private let viewEmitter: ViewEmitter
    
    private init() {
        self.expressionLowerer = ExpressionLowerer(context: loweringContext)
        self.exprEngine = ExpressionEmissionEngine()
        self.viewEmitter = ViewEmitter(exprEngine: exprEngine)
    }
    
    public func lowerExpression(_ expr: ExprSyntaxProtocol) -> IRExpression {
        expressionLowerer.lower(expr)
    }
    
    public func makeView(
        name: String,
        properties: [IRProperty] = [],
        modifiers: [IRModifier] = [],
        children: [IRViewNode] = [],
        statements: [IRStatement] = []
    ) -> IRViewNode {
        let view = IRViewNode(
            componentName: name,
            properties: properties,
            modifiers: modifiers,
            children: children
        )
        view.statements = statements
        return view
    }
    
    public func renderView(_ view: IRViewNode) -> String {
        viewEmitter.emit(view) + "\n"
    }
    
    public func renderView(_ view: IRViewNode, additionalAttributes: [String]) -> String {
        guard !additionalAttributes.isEmpty else {
            return renderView(view)
        }
        
        let rendered = viewEmitter.emit(view)
        let prefix = "<\(view.componentName)"
        let attributes = " " + additionalAttributes.joined(separator: " ")
        
        if let range = rendered.range(of: prefix) {
            let updated = rendered.replacingCharacters(in: range, with: prefix + attributes)
            return updated + "\n"
        }
        
        return rendered + "\n"
    }
    
    public func makeModifier(name: String, arguments: [IRExpression] = []) -> IRModifier {
        IRModifier(name: name, arguments: arguments)
    }
    
    public func renderModifierResults(_ modifier: IRModifier) -> [ModifierResult] {
        modifier.effects.map { effect in
            switch effect {
            case .spacing(let value):
                return .style(key: "padding", value: exprEngine.emit(value))
            case .foregroundColor(let value):
                return .style(key: "color", value: exprEngine.emit(value))
            case .background(let value):
                return .style(key: "background", value: exprEngine.emit(value))
            case .opacity(let value):
                return .style(key: "opacity", value: exprEngine.emit(value))
            case .frame(let width, let height):
                if let w = width { return .style(key: "width", value: exprEngine.emit(w)) }
                if let h = height { return .style(key: "height", value: exprEngine.emit(h)) }
                return .prop(key: "data-frame", value: "true")
            case .interaction(let event, let handler):
                return .prop(key: event, value: exprEngine.emit(handler))
            case .animation(let value):
                return .prop(key: "animation", value: exprEngine.emit(value))
            case .font(let value):
                return .style(key: "font", value: exprEngine.emit(value))
            case .style(let key, let value):
                return .style(key: key, value: exprEngine.emit(value))
            case .custom(let name, _):
                return .prop(key: "data-\(name)", value: "true")
            case .alignment(let value):
                return .style(key: "align-self", value: exprEngine.emit(value))
            case .offset(let x, let y):
                return .style(key: "transform", value: "translate(\(exprEngine.emit(x)), \(exprEngine.emit(y)))")
            }
        }
    }
}
