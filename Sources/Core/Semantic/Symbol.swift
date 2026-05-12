//
//  Symbol.swift
//  swiftjs
//
//  Represents a named symbol in the compiler's symbol table
//

import Foundation

/// A named symbol tracked by the compiler for semantic analysis
public struct Symbol {
    /// The symbol's name as it appears in source
    public let name: String
    
    /// What kind of symbol this is
    public let kind: SymbolKind
    
    /// The inferred or declared type
    public let type: IRType
    
    /// Whether this is a @State variable (requires React useState emission)
    public let isState: Bool
    
    /// Whether this symbol is mutable
    public let isMutable: Bool
    
    /// Source location where symbol was declared
    public let sourceLocation: SourceLocation?
    
    public init(
        name: String,
        kind: SymbolKind,
        type: IRType = .unknown,
        isState: Bool = false,
        isMutable: Bool = false,
        sourceLocation: SourceLocation? = nil
    ) {
        self.name = name
        self.kind = kind
        self.type = type
        self.isState = isState
        self.isMutable = isMutable
        self.sourceLocation = sourceLocation
    }
    
    /// The kinds of symbols the compiler tracks
    public enum SymbolKind {
        /// A @State variable in a component
        case stateVariable
        
        /// A local let/var binding
        case localBinding
        
        /// A function parameter
        case parameter
        
        /// A closure parameter (e.g., $0, named param)
        case closureParam
        
        /// A component/struct name
        case componentName
        
        /// A symbol imported from a module
        case importedSymbol
        
        /// A function declaration
        case function
    }
}
