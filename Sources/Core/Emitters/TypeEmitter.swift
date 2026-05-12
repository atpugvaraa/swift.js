import Foundation

/// Emits TypeScript interfaces from IRSharedModel definitions.
/// This ensures the frontend stays in sync with the Swift backend models.
public final class TypeEmitter {
    public init() {}
    
    public func emit(_ model: IRSharedModel) -> String {
        var out = "export interface \(model.name) {\n"
        for prop in model.properties {
            let optional = prop.isOptional ? "?" : ""
            let tsType = mapToTypeScript(prop.type)
            out += "  \(prop.name)\(optional): \(tsType);\n"
        }
        out += "}\n"
        return out
    }
    
    private func mapToTypeScript(_ type: IRType) -> String {
        switch type {
        case .int, .double:
            return "number"
        case .string:
            return "string"
        case .bool:
            return "boolean"
        case .array(let inner):
            return "\(mapToTypeScript(inner))[]"
        case .optional(let inner):
            return "\(mapToTypeScript(inner)) | null"
        case .void:
            return "void"
        default:
            return "any"
        }
    }
}
