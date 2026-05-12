//
//  IRType.swift
//  swiftjs
//
//  Basic type representation for semantic analysis
//

import Foundation

/// Represents Swift types at the IR level for semantic analysis
/// This is intentionally simplified — we do NOT attempt full Swift type inference.
/// We only track enough type information to make semantic emission decisions.
public indirect enum IRType: Equatable {
    /// Integer types (Int, Int8, Int16, Int32, Int64, UInt, etc.)
    case int

    /// Floating point types (Double, Float, CGFloat)
    case double

    /// String type
    case string

    /// Bool type
    case bool

    /// Color type (SwiftUI.Color)
    case color

    /// Any View type
    case view

    /// Closure/function type with parameter and return types
    case closure(params: [IRType], returnType: IRType)

    /// Array type with element type
    case array(IRType)

    /// Optional type wrapping an inner type
    case optional(IRType)

    /// Void / no return value
    case void

    /// Type cannot be determined statically
    case unknown
}

// MARK: - Type Inference Helpers

extension IRType {
    /// Infer type from a literal expression
    public static func infer(from expression: IRExpression) -> IRType {
        switch expression {
        case .numberLiteral(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0 ? .int : .double
        case .stringLiteral, .interpolatedString:
            return .string
        case .boolLiteral:
            return .bool
        case .nilLiteral:
            return .optional(.unknown)
        case .array(let elements):
            if let first = elements.first {
                return .array(infer(from: first))
            }
            return .array(.unknown)
        case .closure(let closure):
            let paramTypes = closure.parameters.map { _ in IRType.unknown }
            return .closure(params: paramTypes, returnType: .unknown)
        case .view:
            return .view
        default:
            return .unknown
        }
    }

    /// Infer type from a Swift type annotation string
    public static func from(typeAnnotation: String) -> IRType {
        let trimmed = typeAnnotation.trimmingCharacters(in: .whitespacesAndNewlines)

        // Optional
        if trimmed.hasSuffix("?") {
            let inner = String(trimmed.dropLast())
            return .optional(from(typeAnnotation: inner))
        }

        // Array shorthand
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            return .array(from(typeAnnotation: inner))
        }

        switch trimmed {
        case "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return .int
        case "Double", "Float", "CGFloat":
            return .double
        case "String":
            return .string
        case "Bool":
            return .bool
        case "Color":
            return .color
        case "Void", "()":
            return .void
        default:
            return .unknown
        }
    }
}
