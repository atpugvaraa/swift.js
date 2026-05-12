//
//  SymbolTable.swift
//  swiftjs
//
//  Manages the hierarchy of scopes and symbol resolution
//

import Foundation

/// The compiler's symbol table — manages nested scopes and symbol resolution
public class SymbolTable {
    /// The global (outermost) scope
    private let globalScope: Scope
    
    /// The current active scope
    private(set) public var currentScope: Scope
    
    /// Stack of scopes for push/pop management
    private var scopeStack: [Scope] = []
    
    public init() {
        self.globalScope = Scope(kind: .global, name: "global")
        self.currentScope = globalScope
        self.scopeStack = [globalScope]
    }
    
    // MARK: - Scope Management
    
    /// Push a new scope (entering a component, function, closure, or block)
    @discardableResult
    public func pushScope(kind: Scope.ScopeKind, name: String? = nil) -> Scope {
        let scope = Scope(kind: kind, name: name, parent: currentScope)
        scopeStack.append(scope)
        currentScope = scope
        return scope
    }
    
    /// Pop the current scope (leaving it)
    public func popScope() {
        guard scopeStack.count > 1 else { return }
        scopeStack.removeLast()
        currentScope = scopeStack.last!
    }
    
    // MARK: - Symbol Registration
    
    /// Register a symbol in the current scope
    public func register(_ symbol: Symbol) {
        currentScope.register(symbol)
    }
    
    /// Register a state variable
    public func registerStateVariable(name: String, type: IRType, sourceLocation: SourceLocation? = nil) {
        let symbol = Symbol(
            name: name,
            kind: .stateVariable,
            type: type,
            isState: true,
            isMutable: true,
            sourceLocation: sourceLocation
        )
        register(symbol)
    }
    
    /// Register a local variable
    public func registerLocalVariable(name: String, type: IRType = .unknown, isMutable: Bool, sourceLocation: SourceLocation? = nil) {
        let symbol = Symbol(
            name: name,
            kind: .localBinding,
            type: type,
            isMutable: isMutable,
            sourceLocation: sourceLocation
        )
        register(symbol)
    }
    
    /// Register a component name
    public func registerComponent(name: String, sourceLocation: SourceLocation? = nil) {
        let symbol = Symbol(
            name: name,
            kind: .componentName,
            type: .view,
            sourceLocation: sourceLocation
        )
        globalScope.register(symbol)
    }
    
    // MARK: - Symbol Lookup
    
    /// Look up a symbol starting from the current scope
    public func lookup(_ name: String) -> Symbol? {
        currentScope.lookup(name)
    }
    
    /// Check if a name is a state variable
    public func isStateVariable(_ name: String) -> Bool {
        if let symbol = lookup(name) {
            return symbol.isState
        }
        return false
    }
    
    /// Check if a name is defined anywhere in scope
    public func isDefined(_ name: String) -> Bool {
        currentScope.isDefined(name)
    }
    
    /// Get the type of a symbol if known
    public func typeOf(_ name: String) -> IRType {
        lookup(name)?.type ?? .unknown
    }
    
    // MARK: - Scope Depth
    
    /// Current nesting depth
    public var depth: Int {
        scopeStack.count
    }
}
