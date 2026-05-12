import Foundation

/// Defines semantic metadata for component state
public struct IRStateSemantics {
    public let name: String
    public let type: IRType
    public let defaultValue: IRExpression?
    
    public init(name: String, type: IRType, defaultValue: IRExpression? = nil) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
    }
}

/// Defines semantics for state projection (projectedValue / $)
public struct IRStateProjection {
    public let baseName: String
    public let projectedValue: String // e.g. "$name"
    
    public init(baseName: String, projectedValue: String) {
        self.baseName = baseName
        self.projectedValue = projectedValue
    }
}
