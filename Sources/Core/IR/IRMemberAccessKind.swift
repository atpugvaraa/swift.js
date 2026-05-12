//
//  IRMemberAccessKind.swift
//  swiftjs
//
//  Semantic classification of member access expressions
//

import Foundation

/// Distinguishes the semantic kind of a member access expression
/// This enables the emitter to produce correct output for different access patterns
public enum IRMemberAccessKind {
    /// Instance property/method access: `user.name`
    case instance

    /// Static member access: `Color.blue`
    case staticMember

    /// Enum case access: `Alignment.center`
    case enumCase

    /// Module/namespace access: `SwiftUI.Text`
    case namespace

    /// Implicit member access (no base): `.leading`
    case implicit

    /// Fallback until type information is available
    case unknown
}
