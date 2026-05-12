import Foundation

/// Emits a complete IR program as source text
public final class ProgramEmitter {
    private let fileEmitter = FileEmitter()
    
    public init() {}
    
    public func emit(_ program: IRProgram) -> String {
        program.files.map(fileEmitter.emit).joined(separator: "\n\n")
    }
}
