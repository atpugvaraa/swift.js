import Foundation

/// Defines the kind of a binding
public enum IRBindingKind {
    /// @State variable binding ($count)
    case state
    /// @Binding variable binding
    case environment
    /// ObservedObject/StateObject binding
    case observed
    /// Local variable binding (rare in SwiftUI but supported)
    case local
}

/// Semantic representation of a SwiftUI binding ($variable).
public struct IRBinding {
    public let variableName: String
    public let kind: IRBindingKind
    
    public init(variableName: String, kind: IRBindingKind) {
        self.variableName = variableName
        self.kind = kind
    }
}
