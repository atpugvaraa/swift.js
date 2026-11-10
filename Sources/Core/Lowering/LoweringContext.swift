import Foundation
import SwiftSyntax

/// Tracks state and context during the lowering process from SwiftSyntax AST to IR.
/// Manages the symbol table for name resolution and capability registry for validation.
public class LoweringContext {
    /// Constructs that could not be lowered, as errors with source locations
    public private(set) var diagnostics: [DiagnosticMessage] = []

    /// Maps syntax positions to line/column; set per file by FileLowerer
    public var locationConverter: SourceLocationConverter?

    /// File name used in diagnostic locations
    public var fileName = "input.swift"

    /// Methods and function props of the View being lowered; calls to them are emitted as-is
    public var viewMethods: Set<String> = []

    /// Props (stored properties set by the caller) of each View struct in the file, in order
    public var viewProps: [String: [IRClosureParameter]] = [:]

    /// Model structs in the file (non-View structs), usable as TypeScript types
    public var modelTypes: Set<String> = []

    /// Swift types with a direct TypeScript equivalent, or nil.
    public func typeScriptType(_ type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil {
            switch identifier.name.text {
            case "String", "Character", "UUID": return "string"
            case "Int", "Double", "Float", "CGFloat": return "number"
            case "Bool": return "boolean"
            case let name where modelTypes.contains(name): return name
            default: return nil
            }
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return typeScriptType(array.element).map { $0.contains(" ") ? "(\($0))[]" : "\($0)[]" }
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return typeScriptType(optional.wrappedType).map { "\($0) | null" }  // nil is emitted as null
        }
        if let function = type.as(FunctionTypeSyntax.self), function.parameters.isEmpty,
           function.effectSpecifiers == nil,
           function.returnClause.type.as(IdentifierTypeSyntax.self)?.name.text == "Void" {
            return "() => void"
        }
        return nil
    }
    
    /// The symbol table for tracking definitions across scopes
    public let symbolTable: SymbolTable
    
    /// Registry of supported runtime components and modifiers
    public let capabilityRegistry: CapabilityRegistry
    
    /// Central registry for component detection (runtime vs custom)
    public let componentRegistry: ComponentRegistry
    
    /// Imported modules tracking
    public private(set) var imports: [IRImport] = []
    
    /// State variables declared at component level
    public private(set) var stateVariables: [IRStateVariable] = []
    
    /// Tracks components used in the current file to generate precise imports
    public private(set) var usedComponents: Set<String> = []
    
    public init() {
        self.symbolTable = SymbolTable()
        self.capabilityRegistry = CapabilityRegistry()
        self.capabilityRegistry.registerDefaults()
        self.componentRegistry = ComponentRegistry()
    }
    
    // MARK: - Variable Management
    
    public func registerVariable(_ name: String, value: IRExpression, isMutable: Bool = true) {
        let type = IRType.infer(from: value)
        symbolTable.registerLocalVariable(name: name, type: type, isMutable: isMutable)
    }
    
    public func lookupVariable(_ name: String) -> Symbol? {
        return symbolTable.lookup(name)
    }
    
    public func isVariableDefined(_ name: String) -> Bool {
        return symbolTable.isDefined(name)
    }
    
    // MARK: - Diagnostics
    
    /// Records valid Swift that swift.js cannot translate yet. Any such error fails transpilation.
    public func addDiagnostic(_ message: String, at node: (any SyntaxProtocol)? = nil) {
        let location = node.flatMap { node in
            locationConverter.map { SourceLocation.from(node, converter: $0, file: fileName) }
        }
        diagnostics.append(DiagnosticMessage(severity: .error, message: message, sourceLocation: location))
    }
    
    // MARK: - Imports
    
    public func addImport(_ swiftImport: IRImport) {
        imports.append(swiftImport)
    }
    
    // MARK: - State Variables
    
    public func addStateVariable(_ variable: IRStateVariable) {
        stateVariables.append(variable)
        symbolTable.registerStateVariable(name: variable.name, type: variable.inferredType)
    }
    // MARK: - Component Tracking
    
    public func markComponentUsed(_ name: String) {
        usedComponents.insert(name)
    }
}
