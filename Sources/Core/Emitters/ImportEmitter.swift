import Foundation

/// Emits ES module import statements from IR imports
public final class ImportEmitter {
    public init() {}
    
    public func emit(_ irImport: IRImport) -> String {
        guard !irImport.items.isEmpty else {
            return "import '\(irImport.module)';"
        }
        
        let items = irImport.items.sorted().joined(separator: ", ")
        return "import { \(items) } from '\(irImport.module)';"
    }
}
