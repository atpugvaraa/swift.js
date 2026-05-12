import Foundation

/// Shared formatting state for emitters
public final class EmitterContext {
    public var indentationLevel: Int = 0
    public var indentationUnit: String = "  "
    
    public init() {}
    
    public func indent() {
        indentationLevel += 1
    }
    
    public func outdent() {
        indentationLevel = max(0, indentationLevel - 1)
    }
    
    public func linePrefix() -> String {
        String(repeating: indentationUnit, count: indentationLevel)
    }
    
    public func indentLines(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.isEmpty ? "" : linePrefix() + line
            }
            .joined(separator: "\n")
    }
}
