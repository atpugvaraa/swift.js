import Foundation
import SwiftSyntax

/// Converts SwiftUI modifiers to semantic IR modifiers with understood effects
public class ModifierLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer
    
    public init(context: LoweringContext, exprLowerer: ExpressionLowerer) {
        self.context = context
        self.exprLowerer = exprLowerer
    }
    
    public func lower(_ callExpr: FunctionCallExprSyntax) -> IRModifier? {
        guard let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }
        
        let modifierName = memberAccess.declName.baseName.text
        
        // Validate against registry
        if !context.capabilityRegistry.supportsModifier(modifierName) {
            context.addDiagnostic("⚠️ Unsupported modifier: \(modifierName)")
        }

        let arguments = callExpr.arguments.map { arg -> IRExpression in
            exprLowerer.lower(arg.expression)
        }
        
        let modifier = IRModifier(
            name: modifierName,
            arguments: arguments
        )
        
        // Determine and add semantic effects
        let effects = determineModifierEffects(modifierName: modifierName, arguments: arguments)
        modifier.effects = effects
        
        return modifier
    }
    
    private func determineModifierEffects(modifierName: String, arguments: [IRExpression]) -> [IRModifierEffect] {
        var effects: [IRModifierEffect] = []
        
        switch modifierName {
        case "frame":
            // Swift: .frame(width: 100, height: 200)
            // Simplified logic: first is width, second is height if present
            let width = arguments.count > 0 ? arguments[0] : nil
            let height = arguments.count > 1 ? arguments[1] : nil
            effects.append(.frame(width: width, height: height))
            
        case "padding":
            let value = arguments.first ?? .numberLiteral(16) // Default padding
            effects.append(.spacing(value))
            
        case "foregroundColor", "foregroundStyle":
            if let value = arguments.first {
                effects.append(.foregroundColor(value))
            }
            
        case "background":
            if let value = arguments.first {
                effects.append(.background(value))
            }
            
        case "opacity":
            if let value = arguments.first {
                effects.append(.opacity(value))
            }
            
        case "onTapGesture":
            if let handler = arguments.first {
                effects.append(.interaction(event: "onTap", handler: handler))
            }
            
        case "animation":
            if let animation = arguments.first {
                effects.append(.animation(animation))
            }
            
        default:
            effects.append(.custom(name: modifierName, arguments: arguments))
        }
        
        return effects
    }
}
