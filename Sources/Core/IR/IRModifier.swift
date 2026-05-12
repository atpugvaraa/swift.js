//
//  IRModifier.swift
//  swiftjs
//
//  Intermediate Representation of a view modifier
//

import Foundation

/// A SwiftUI modifier applied to a view
/// Examples: padding(), foregroundStyle(), background(), opacity()
public class IRModifier: BaseIRNode {
    public let name: String                      // "padding", "foregroundStyle", etc.
    public let arguments: [IRExpression]         // Evaluated arguments to the modifier
    public var effects: [IRModifierEffect] = []  // What this modifier does semantically
    
    public init(
        name: String,
        arguments: [IRExpression] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.arguments = arguments
        super.init(sourceLocation: sourceLocation)
    }
    
    /// Add an effect to this modifier
    public func addEffect(_ effect: IRModifierEffect) {
        effects.append(effect)
    }
}
