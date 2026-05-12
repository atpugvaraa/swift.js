//
//  IRViewNode.swift
//  swiftjs
//
//  Intermediate Representation of a SwiftUI view
//

import Foundation

/// A SwiftUI view in intermediate representation
/// Represents views like Text, Button, VStack, etc. with their properties, modifiers, and children
public class IRViewNode: BaseIRNode {
    public let componentName: String           // "Text", "Button", "VStack"
    public let properties: [IRProperty]        // Named props (e.g., content, label)
    public var modifiers: [IRModifier]         // Applied modifiers (can be mutated)
    public let children: [IRViewNode]          // Child views in composition
    public var statements: [IRStatement] = []  // Closure statements (e.g., Button action)
    
    public init(
        componentName: String,
        properties: [IRProperty] = [],
        modifiers: [IRModifier] = [],
        children: [IRViewNode] = [],
        statements: [IRStatement] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.componentName = componentName
        self.properties = properties
        self.modifiers = modifiers
        self.children = children
        self.statements = statements
        super.init(sourceLocation: sourceLocation)
    }
    
    // MARK: - Modifier Application
    
    /// Apply a modifier to this view
    public func applyModifier(_ modifier: IRModifier) {
        modifiers.append(modifier)
    }
    
    /// Apply multiple modifiers to this view
    public func applyModifiers(_ modifiers: [IRModifier]) {
        self.modifiers.append(contentsOf: modifiers)
    }
}
