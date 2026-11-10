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

/// One Swift file of a module and the TypeScript module it is emitted to (e.g. "@/views/Row").
public struct TranspileInput {
    public let fileName: String
    public let source: String
    public let module: String

    public init(fileName: String, source: String, module: String) {
        self.fileName = fileName
        self.source = source
        self.module = module
    }
}

public class Transpiler {
    public init() {}

    /// Transpiles all files of a Swift module together, so Views and models declared in one
    /// file can be used (and are imported) in the others. Results are in input order.
    public func transpile(project inputs: [TranspileInput]) -> [Result<String, TranspileError>] {
        let parsed = inputs.map { Parser.parse(source: $0.source) }
        let symbols = ProjectSymbols.collect(zip(parsed, inputs).map { ($0, $1.module) })
        return zip(parsed, inputs).map { syntax, input in
            Result { try transpile(syntax, fileName: input.fileName, project: symbols, module: input.module) }
                .mapError { $0 as! TranspileError }
        }
    }

    /// Transpiles SwiftUI source to TSX: parse → lower to IR (with semantic analysis) → emit.
    /// Throws `TranspileError` rather than emitting TSX for anything it cannot translate.
    public func transpile(_ source: String, fileName: String = "input.swift") throws -> String {
        try transpile(Parser.parse(source: source), fileName: fileName, project: ProjectSymbols(), module: "")
    }

    private func transpile(_ sourceFile: SourceFileSyntax, fileName: String,
                           project: ProjectSymbols, module: String) throws -> String {
        let lowerer = FileLowerer()
        let irFile = lowerer.lower(sourceFile, fileName: fileName, project: project, module: module)

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
