import Foundation

/// Describes the capabilities of a runtime component
public struct RuntimeComponentCapability {
    /// Component name (e.g., "Text", "Button", "VStack")
    public let name: String
    
    /// Properties this component supports (e.g., ["content", "label", "alignment"])
    public let supportedProperties: [String]
    
    /// Modifiers this component specifically supports beyond universal modifiers
    public let supportedModifiers: [String]
    
    /// Whether this component can contain child views
    public let supportsChildren: Bool
    
    /// Whether this component supports two-way bindings ($binding syntax)
    public let supportsBindings: Bool
    
    /// Whether this component supports event handlers
    public let supportsEvents: Bool
    
    public init(
        name: String,
        supportedProperties: [String] = [],
        supportedModifiers: [String] = [],
        supportsChildren: Bool = false,
        supportsBindings: Bool = false,
        supportsEvents: Bool = false
    ) {
        self.name = name
        self.supportedProperties = supportedProperties
        self.supportedModifiers = supportedModifiers
        self.supportsChildren = supportsChildren
        self.supportsBindings = supportsBindings
        self.supportsEvents = supportsEvents
    }
}

/// Tracks which SwiftUI components and modifiers the runtime can actually render.
/// Provides rich capability information for compile-time validation.
public final class CapabilityRegistry {
    private var components: [String: RuntimeComponentCapability] = [:]
    private var supportedModifiers: Set<String> = []
    
    public init() {}
    
    // MARK: - Registration
    
    /// Register a component with full capability information
    public func registerComponent(_ capability: RuntimeComponentCapability) {
        components[capability.name] = capability
    }
    
    /// Register a component by name only (backward compatibility)
    public func registerComponent(_ name: String) {
        if components[name] == nil {
            components[name] = RuntimeComponentCapability(name: name)
        }
    }
    
    /// Register a modifier as supported
    public func registerModifier(_ name: String) {
        supportedModifiers.insert(name)
    }
    
    // MARK: - Queries
    
    /// Check if a component is supported
    public func supportsComponent(_ name: String) -> Bool {
        components[name] != nil
    }
    
    /// Check if a modifier is supported
    public func supportsModifier(_ name: String) -> Bool {
        supportedModifiers.contains(name)
    }
    
    /// Get full capability info for a component
    public func capability(for name: String) -> RuntimeComponentCapability? {
        components[name]
    }
    
    /// Check if a specific property is supported on a component
    public func supportsProperty(_ property: String, on component: String) -> Bool {
        guard let cap = components[component] else { return false }
        return cap.supportedProperties.contains(property)
    }
    
    /// Check if a component supports children
    public func supportsChildren(_ component: String) -> Bool {
        components[component]?.supportsChildren ?? false
    }
    
    /// All registered component names
    public func allComponents() -> [String] {
        components.keys.sorted()
    }
    
    /// All registered modifier names
    public func allModifiers() -> [String] {
        supportedModifiers.sorted()
    }
    
    /// Components used but not registered
    public func missingComponents(from names: [String]) -> [String] {
        names.filter { !supportsComponent($0) }.sorted()
    }
    
    /// Modifiers used but not registered
    public func missingModifiers(from names: [String]) -> [String] {
        names.filter { !supportsModifier($0) }.sorted()
    }
    
    // MARK: - Default Registration
    
    /// Register what swift.js can render with @swiftuijs/ui today. Only list a component or
    /// property here once its whole path (lowering, emission, swiftuijs props) works;
    /// anything else is reported as not yet supported.
    public func registerDefaults() {
        let components: [(String, [String])] = [
            ("Text", ["content"]),
            ("Button", ["title", "action"]),
            ("VStack", ["alignment", "spacing"]),
            ("HStack", ["alignment", "spacing"]),
            ("ZStack", ["alignment"]),
            ("Spacer", ["minLength"]),
            ("ScrollView", ["showsIndicators"]),
            ("TextField", ["placeholder", "text"]),
            ("SecureField", ["placeholder", "text"]),
            ("Toggle", ["label", "isOn"]),
        ]
        for (name, properties) in components {
            registerComponent(RuntimeComponentCapability(name: name, supportedProperties: properties))
        }

        for modifier in ModifierLowerer.supportedModifiers {
            registerModifier(modifier)
        }
    }
}
