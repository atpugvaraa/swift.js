import Foundation

/// Orchestrates the execution of multiple compiler passes in a specific order.
public class PassPipeline {
    private var passes: [CompilerPass] = []
    private let context: CompilerPassContext
    
    public init(context: CompilerPassContext) {
        self.context = context
    }
    
    /// Add a pass to the end of the pipeline
    public func addPass(_ pass: CompilerPass) {
        passes.append(pass)
    }
    
    /// Execute all registered passes on the program
    public func execute(on program: IRFile) throws {
        for pass in passes {
            try pass.run(on: program, context: context)
        }
    }
}
