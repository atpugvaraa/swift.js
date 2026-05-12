//
//  SourceLocation.swift
//  swiftjs
//
//  Error reporting context with source position info
//

import Foundation
import SwiftSyntax

/// Tracks source location for error reporting and debugging
public struct SourceLocation: CustomStringConvertible {
    public let file: String
    public let line: Int
    public let column: Int
    public let length: Int
    
    public init(file: String, line: Int, column: Int, length: Int = 1) {
        self.file = file
        self.line = line
        self.column = column
        self.length = length
    }
    
    /// Extract SourceLocation from a SwiftSyntax node
    public static func from(_ node: SyntaxProtocol, file: String = "input.swift") -> SourceLocation {
        // For now, use simplified location info
        // SwiftSyntax doesn't expose line/column directly on AbsolutePosition in all versions
        return SourceLocation(
            file: file,
            line: 1,
            column: 1,
            length: node.trimmedLength.utf8Length
        )
    }
    
    public var description: String {
        return "\(file):\(line):\(column)"
    }
}
