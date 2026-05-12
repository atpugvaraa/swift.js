import Foundation

/// Context provided to every compiler pass during execution.
/// Contains shared state like diagnostics, symbol table, and capability registry.
public class CompilerPassContext {
    public let diagnostics: DiagnosticsCollector
    public let symbolTable: SymbolTable
    public let capabilityRegistry: CapabilityRegistry
    public let componentRegistry: ComponentRegistry
    
    public init(
        diagnostics: DiagnosticsCollector,
        symbolTable: SymbolTable,
        capabilityRegistry: CapabilityRegistry,
        componentRegistry: ComponentRegistry
    ) {
        self.diagnostics = diagnostics
        self.symbolTable = symbolTable
        self.capabilityRegistry = capabilityRegistry
        self.componentRegistry = componentRegistry
    }
}

/// A single pass in the compiler pipeline that can inspect and mutate the IR.
public protocol CompilerPass {
    /// Human-readable name of the pass
    var name: String { get }
    
    /// Execute the pass on the given IR program
    func run(on program: IRFile, context: CompilerPassContext) throws
}
