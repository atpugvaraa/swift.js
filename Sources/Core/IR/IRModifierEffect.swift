import Foundation

/// Semantic representation of a SwiftUI modifier effect.
/// Decouples lowering from platform-specific emission (like CSS/styles).
public enum IRModifierEffect {
    /// Padding or spacing around an element
    case spacing(IRExpression)
    
    /// Foreground color or style
    case foregroundColor(IRExpression)
    
    /// Background view or color
    case background(IRExpression)
    
    /// Opacity/Alpha transparency
    case opacity(IRExpression)
    
    /// Fixed or flexible frame dimensions
    case frame(
        width: IRExpression?,
        height: IRExpression?
    )
    
    /// Animation settings
    case animation(IRExpression)
    
    /// Font settings
    case font(IRExpression)
    
    /// User interaction handlers (onTap, etc.)
    case interaction(
        event: String,
        handler: IRExpression
    )
    
    /// Alignment within a container
    case alignment(IRExpression)
    
    /// Offset/Translation
    case offset(x: IRExpression, y: IRExpression)
    
    /// Custom or unsupported modifier fallback
    case custom(
        name: String,
        arguments: [IRExpression]
    )
    
    /// Legacy style property bridge
    case style(key: String, value: IRExpression)
}
