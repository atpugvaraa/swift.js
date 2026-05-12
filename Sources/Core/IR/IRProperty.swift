//
//  IRProperty.swift
//  swiftjs
//
//  Intermediate Representation of a property/prop on a view
//

import Foundation

/// A property or prop on a SwiftUI/React view
/// Examples: content, label, style, alignment, spacing
public class IRProperty: BaseIRNode {
    public let name: String           // "content", "label", "style"
    public let value: IRExpression    // The value of the property
    
    public init(
        name: String,
        value: IRExpression,
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.value = value
        super.init(sourceLocation: sourceLocation)
    }
}
