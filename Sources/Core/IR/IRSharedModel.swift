import Foundation

/// Represents a data model that is shared between the Hummingbird backend
/// and the React frontend. This allows for type-safe full-stack Swift.
public class IRSharedModel: BaseIRNode {
    public let name: String
    public let properties: [IRModelProperty]
    public let conformances: [String]
    
    public init(
        name: String,
        properties: [IRModelProperty] = [],
        conformances: [String] = ["Codable"],
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.properties = properties
        self.conformances = conformances
        super.init(sourceLocation: sourceLocation)
    }
}

/// A property within a shared model
public struct IRModelProperty {
    public let name: String
    public let type: IRType
    public let isOptional: Bool
    
    public init(name: String, type: IRType, isOptional: Bool = false) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
    }
}
