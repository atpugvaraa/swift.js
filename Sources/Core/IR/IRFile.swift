//
//  IRFile.swift
//  swiftjs
//
//  Intermediate Representation of a complete Swift file
//

import Foundation

/// A Swift file lowered to intermediate representation
public class IRFile: BaseIRNode {
    public let imports: [IRImport]          // Import statements
    public let statements: [IRStatement]    // Top-level statements
    public let components: [IRComponent]    // Components (structs with View body)
    
    public init(
        imports: [IRImport] = [],
        statements: [IRStatement] = [],
        components: [IRComponent] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.imports = imports
        self.statements = statements
        self.components = components
        super.init(sourceLocation: sourceLocation)
    }
}

// MARK: - Import Statement

/// An import statement in IR form
public class IRImport: BaseIRNode {
    public let items: [String]              // ["VStack", "Button", "Text"]
    public let module: String               // "@swiftjs/runtime"
    
    public init(
        items: [String],
        module: String,
        sourceLocation: SourceLocation? = nil
    ) {
        self.items = items
        self.module = module
        super.init(sourceLocation: sourceLocation)
    }
}

// MARK: - Component

/// A top-level component (Swift struct with @View or body variable)
public class IRComponent: BaseIRNode {
    public let name: String                          // Component name
    public let stateVariables: [IRStateVariable]    // @State variables
    public let body: IRViewNode?                    // The view body
    public let isDefaultExport: Bool                // true for "Page" component
    
    public init(
        name: String,
        stateVariables: [IRStateVariable] = [],
        body: IRViewNode? = nil,
        isDefaultExport: Bool = false,
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.stateVariables = stateVariables
        self.body = body
        self.isDefaultExport = isDefaultExport
        super.init(sourceLocation: sourceLocation)
    }
}

// MARK: - State Variable

/// A @State variable in a component
public class IRStateVariable: BaseIRNode {
    public let name: String               // Variable name
    public let initialValue: IRExpression // Initial value
    public let type: String?              // Type annotation (optional)
    public let inferredType: IRType       // Semantically inferred type
    
    public init(
        name: String,
        initialValue: IRExpression,
        type: String? = nil,
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.initialValue = initialValue
        self.type = type
        // Infer type from annotation if available, otherwise from initial value
        if let typeAnnotation = type {
            self.inferredType = IRType.from(typeAnnotation: typeAnnotation)
        } else {
            self.inferredType = IRType.infer(from: initialValue)
        }
        super.init(sourceLocation: sourceLocation)
    }
}
