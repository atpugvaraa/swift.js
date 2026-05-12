//
//  IRNode.swift
//  swiftjs
//
//  Intermediate Representation base protocol for all IR nodes
//

import Foundation

/// Base protocol for all SwiftJS Intermediate Representation nodes
public protocol IRNode {
    /// Source location for error reporting
    var sourceLocation: SourceLocation? { get set }
    
    /// Unique identifier for this node
    var id: UUID { get }
}

/// Common conformance helper for concrete IR node types (classes)
open class BaseIRNode: IRNode {
    public var sourceLocation: SourceLocation?
    public let id: UUID = UUID()
    
    public init(sourceLocation: SourceLocation? = nil) {
        self.sourceLocation = sourceLocation
    }
}
