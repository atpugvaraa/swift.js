import Foundation

/// Defines the kind of a SwiftUI component
public enum ComponentKind {
    /// A built-in runtime view (Text, Button, etc.)
    case runtimeView
    /// A custom view defined in Swift source
    case customView
    /// A primitive HTML-like element
    case primitive
}

/// Metadata about a SwiftUI component
public struct ComponentDefinition {
    public let name: String
    public let kind: ComponentKind
    public let supportsChildren: Bool
    public let supportedModifiers: [String]
    
    public init(
        name: String,
        kind: ComponentKind,
        supportsChildren: Bool = false,
        supportedModifiers: [String] = []
    ) {
        self.name = name
        self.kind = kind
        self.supportsChildren = supportsChildren
        self.supportedModifiers = supportedModifiers
    }
}

/// Central registry of all known SwiftUI components.
/// Replaces legacy uppercase heuristics for view detection.
public final class ComponentRegistry {
    private var components: [String: ComponentDefinition] = [:]
    
    public init() {
        registerDefaults()
    }
    
    /// Register a component definition
    public func register(_ definition: ComponentDefinition) {
        components[definition.name] = definition
    }
    
    /// Check if a name refers to a registered component
    public func isComponent(_ name: String) -> Bool {
        return components[name] != nil
    }
    
    /// Get definition for a component
    public func definition(for name: String) -> ComponentDefinition? {
        return components[name]
    }
    
    /// Register standard SwiftUI components
    private func registerDefaults() {
        let runtimeViews = [
            ComponentDefinition(name: "Text", kind: .runtimeView),
            ComponentDefinition(name: "Button", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "VStack", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "HStack", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "ZStack", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "ScrollView", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "NavigationStack", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "Spacer", kind: .runtimeView),
            ComponentDefinition(name: "TextField", kind: .runtimeView),
            ComponentDefinition(name: "Image", kind: .runtimeView),
            ComponentDefinition(name: "Divider", kind: .runtimeView),
            ComponentDefinition(name: "List", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "ForEach", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "Section", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "Toggle", kind: .runtimeView),
            ComponentDefinition(name: "Label", kind: .runtimeView),
            ComponentDefinition(name: "Slider", kind: .runtimeView),
            ComponentDefinition(name: "Stepper", kind: .runtimeView),
            ComponentDefinition(name: "Picker", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "DatePicker", kind: .runtimeView),
            ComponentDefinition(name: "ColorPicker", kind: .runtimeView),
            ComponentDefinition(name: "SecureField", kind: .runtimeView),
            ComponentDefinition(name: "NavigationLink", kind: .runtimeView, supportsChildren: true),
            ComponentDefinition(name: "TabView", kind: .runtimeView, supportsChildren: true)
        ]
        
        for view in runtimeViews {
            register(view)
        }
    }
}
