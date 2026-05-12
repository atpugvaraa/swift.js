import Foundation

/// A single diagnostic emitted by the compiler pipeline
public struct DiagnosticMessage: Identifiable {
    public enum Severity: String {
        case error
        case warning
        case info
    }
    
    public let id = UUID()
    public let severity: Severity
    public let message: String
    public let sourceLocation: SourceLocation?
    
    public init(severity: Severity, message: String, sourceLocation: SourceLocation? = nil) {
        self.severity = severity
        self.message = message
        self.sourceLocation = sourceLocation
    }
}

/// Collects diagnostics during lowering, validation, and emission
public final class DiagnosticsCollector {
    private(set) public var messages: [DiagnosticMessage] = []
    
    public init() {}
    
    public func emit(_ severity: DiagnosticMessage.Severity, _ message: String, sourceLocation: SourceLocation? = nil) {
        messages.append(DiagnosticMessage(severity: severity, message: message, sourceLocation: sourceLocation))
    }
    
    public func error(_ message: String, sourceLocation: SourceLocation? = nil) {
        emit(.error, message, sourceLocation: sourceLocation)
    }
    
    public func warning(_ message: String, sourceLocation: SourceLocation? = nil) {
        emit(.warning, message, sourceLocation: sourceLocation)
    }
    
    public func info(_ message: String, sourceLocation: SourceLocation? = nil) {
        emit(.info, message, sourceLocation: sourceLocation)
    }
    
    public func hasErrors() -> Bool {
        messages.contains { $0.severity == .error }
    }
    
    public func clear() {
        messages.removeAll()
    }
}
