import Foundation
import SwiftSyntax

/// Tracks state and context during the lowering process from SwiftSyntax AST to IR.
/// Manages the symbol table for name resolution and capability registry for validation.
public class LoweringContext {
    /// Diagnostic messages collected during lowering
    public private(set) var diagnostics: [String] = []
    
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
    
    public func addDiagnostic(_ message: String) {
        diagnostics.append(message)
    }
    
    public func hasErrors() -> Bool {
        return diagnostics.contains { $0.lowercased().contains("error") }
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
