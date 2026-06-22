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
        return cap.supportedProperties.isEmpty || cap.supportedProperties.contains(property)
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
    
    /// Register the default set of runtime capabilities
    public func registerDefaults() {
        registerComponent(RuntimeComponentCapability(
            name: "Text",
            supportedProperties: ["content"],
            supportsChildren: false,
            supportsEvents: false
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Button",
            supportedProperties: ["title", "label", "action"],
            supportsChildren: true,
            supportsEvents: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "VStack",
            supportedProperties: ["alignment", "spacing"],
            supportsChildren: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "HStack",
            supportedProperties: ["alignment", "spacing"],
            supportsChildren: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "ZStack",
            supportedProperties: ["alignment"],
            supportsChildren: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "ScrollView",
            supportedProperties: ["axis", "showsIndicators"],
            supportsChildren: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Spacer",
            supportedProperties: [],
            supportsChildren: false
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Image",
            supportedProperties: ["src", "systemName"],
            supportsChildren: false
        ))
        registerComponent(RuntimeComponentCapability(
            name: "TextField",
            supportedProperties: ["placeholder", "text"],
            supportsChildren: false,
            supportsBindings: true,
            supportsEvents: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Toggle",
            supportedProperties: ["isOn", "label"],
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Label",
            supportedProperties: ["title", "systemImage"]
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Slider",
            supportedProperties: ["value", "min", "max", "step", "onChange"],
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Stepper",
            supportedProperties: ["value", "min", "max", "step", "onChange", "label"],
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "Picker",
            supportedProperties: ["selection", "label", "options"],
            supportsChildren: true,
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "DatePicker",
            supportedProperties: ["selection", "label"],
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "ColorPicker",
            supportedProperties: ["selection", "label"],
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "SecureField",
            supportedProperties: ["text", "placeholder"],
            supportsBindings: true,
            supportsEvents: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "NavigationLink",
            supportedProperties: ["href", "target", "replace", "destination", "label"],
            supportsChildren: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "TabView",
            supportedProperties: ["initialTab", "labels", "selection"],
            supportsChildren: true,
            supportsBindings: true
        ))
        registerComponent(RuntimeComponentCapability(
            name: "NavigationStack",
            supportedProperties: ["initialRoute"],
            supportsChildren: true
        ))

        
        // Register all supported modifiers
        for modifier in [
            "padding", "background", "opacity", "blendMode",
            "foregroundStyle", "font", "fontWeight",
            "frame", "ignoresSafeArea",
            "onTapGesture", "onHover",
            "rotationEffect", "scaleEffect", "animation",
            "cornerRadius", "foregroundColor", "backgroundColor"
        ] {
            registerModifier(modifier)
        }
    }
}
