//
//  Transpiler.swift
//  swiftjs
//
//  Created by Aarav Gupta on 28/12/25.
//

import Foundation
import SwiftSyntax
import SwiftParser

public class Transpiler {
    public init() {}

    /// Transpiles SwiftUI source to TSX: parse → lower to IR (with semantic analysis) → emit.
    public func transpile(_ source: String) -> String {
        let sourceFile = Parser.parse(source: source)

        let lowerer = FileLowerer()
        let irFile = lowerer.lower(sourceFile)
        var output = FileEmitter().emit(irFile)

        let diagnostics = lowerer.getDiagnostics()
        if !diagnostics.isEmpty {
            let diagnosticComments = diagnostics.map { "// \($0)" }.joined(separator: "\n")
            output = diagnosticComments + "\n\n" + output
        }

        return output
    }
}
