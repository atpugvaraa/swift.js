//
//  Transpiler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Valid Swift that swift.js cannot translate yet, with the location of each construct.
public struct TranspileError: Error, CustomStringConvertible {
    public let diagnostics: [DiagnosticMessage]

    public var description: String {
        diagnostics.map(\.description).joined(separator: "\n")
    }
}

public class Transpiler {
    public init() {}

    /// Transpiles SwiftUI source to TSX: parse → lower to IR (with semantic analysis) → emit.
    /// Throws `TranspileError` rather than emitting TSX for anything it cannot translate.
    public func transpile(_ source: String, fileName: String = "input.swift") throws -> String {
        let sourceFile = Parser.parse(source: source)

        let lowerer = FileLowerer()
        let irFile = lowerer.lower(sourceFile, fileName: fileName)

        let diagnostics = lowerer.getDiagnostics()
        guard diagnostics.isEmpty else {
            let byPosition = diagnostics.sorted {
                ($0.sourceLocation?.line ?? 0, $0.sourceLocation?.column ?? 0)
                    < ($1.sourceLocation?.line ?? 0, $1.sourceLocation?.column ?? 0)
            }
            throw TranspileError(diagnostics: byPosition)
        }

        return FileEmitter().emit(irFile)
    }
}
