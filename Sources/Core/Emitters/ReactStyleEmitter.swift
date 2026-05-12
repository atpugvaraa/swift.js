import Foundation

/// Emitter that converts semantic IRModifierEffects into React style objects.
/// Separates semantic meaning from CSS implementation details.
public class ReactStyleEmitter {
    private let exprEngine: ExpressionEmissionEngine
    
    public init(exprEngine: ExpressionEmissionEngine) {
        self.exprEngine = exprEngine
    }
    
    /// Convert a list of semantic effects into a CSS style object string
    public func emitStyleObject(from effects: [IRModifierEffect]) -> String {
        var styleProps: [String: String] = [:]
        
        for effect in effects {
            switch effect {
            case .spacing(let value):
                styleProps["padding"] = exprEngine.emit(value)
                
            case .foregroundColor(let value):
                styleProps["color"] = exprEngine.emit(value)
                
            case .background(let value):
                styleProps["background"] = exprEngine.emit(value)
                
            case .opacity(let value):
                styleProps["opacity"] = exprEngine.emit(value)
                
            case .frame(let width, let height):
                if let w = width { styleProps["width"] = exprEngine.emit(w) }
                if let h = height { styleProps["height"] = exprEngine.emit(h) }
                
            case .alignment(let value):
                // Simplified: maps to flex-box alignment
                styleProps["alignSelf"] = exprEngine.emit(value)
                
            case .offset(let x, let y):
                styleProps["transform"] = "`translate(${" + exprEngine.emit(x) + "}, ${" + exprEngine.emit(y) + "})`"
                
            case .font(let value):
                styleProps["font"] = exprEngine.emit(value)
                
            case .style(let key, let value):
                styleProps[key] = exprEngine.emit(value)
                
            case .interaction, .animation, .custom:
                // These are usually handled as separate props or wrapper components
                break
            }
        }
        
        if styleProps.isEmpty { return "" }
        
        let props = styleProps.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "{ \(props) }"
    }
}
