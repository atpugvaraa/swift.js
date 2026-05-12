//
//  Scope.swift
//  swiftjs
//
//  Represents a lexical scope containing symbol definitions
//

import Foundation

/// A single lexical scope in the symbol table
/// Scopes are nested (function > closure > block etc.)
public class Scope {
    /// Symbols defined in this scope
    private var symbols: [String: Symbol] = [:]
    
    /// Parent scope (nil for the global scope)
    public weak var parent: Scope?
    
    /// What kind of scope this is
    public let kind: ScopeKind
    
    /// The name of this scope (e.g., component name, function name)
    public let name: String?
    
    public init(kind: ScopeKind, name: String? = nil, parent: Scope? = nil) {
        self.kind = kind
        self.name = name
        self.parent = parent
    }
    
    /// Kinds of scopes
    public enum ScopeKind {
        case global
        case component
        case function
        case closure
        case block     // if/for/while etc.
    }
    
    // MARK: - Symbol Management
    
    /// Register a symbol in this scope
    public func register(_ symbol: Symbol) {
        symbols[symbol.name] = symbol
    }
    
    /// Look up a symbol in this scope only (not parents)
    public func localLookup(_ name: String) -> Symbol? {
        symbols[name]
    }
    
    /// Look up a symbol, walking up the scope chain
    public func lookup(_ name: String) -> Symbol? {
        if let symbol = symbols[name] {
            return symbol
        }
        return parent?.lookup(name)
    }
    
    /// Check if a symbol is defined in this scope or any parent
    public func isDefined(_ name: String) -> Bool {
        lookup(name) != nil
    }
    
    /// All symbols in this scope (not including parents)
    public var localSymbols: [Symbol] {
        Array(symbols.values)
    }
}
