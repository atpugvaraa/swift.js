import Foundation
import SwiftSyntax

/// Converts SwiftUI view syntax to semantic IR view nodes
public class ViewLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer
    private let modifierLowerer: ModifierLowerer
    
    private var stmtLowerer: StatementLowerer?
    
    public init(context: LoweringContext, exprLowerer: ExpressionLowerer, modifierLowerer: ModifierLowerer) {
        self.context = context
        self.exprLowerer = exprLowerer
        self.modifierLowerer = modifierLowerer
    }
    
    public func setStatementLowerer(_ stmtLowerer: StatementLowerer) {
        self.stmtLowerer = stmtLowerer
    }
    
    public func lowerViewCall(_ callExpr: FunctionCallExprSyntax) -> IRViewNode? {
        guard let componentName = extractComponentName(callExpr.calledExpression) else {
            return nil
        }
        
        // Ensure it's a registered component (either runtime or custom)
        guard context.componentRegistry.isComponent(componentName) else {
            return nil
        }
        // Validate runtime capabilities
        let isRuntimeView = context.componentRegistry.definition(for: componentName)?.kind == .runtimeView
        let isSupported = context.capabilityRegistry.supportsComponent(componentName)
        
        if isRuntimeView && !isSupported {
            context.addDiagnostic("⚠️ Unsupported runtime component: \(componentName)")
        } else {
            context.markComponentUsed(componentName)
        }

        var properties: [IRProperty] = []
        for (index, arg) in callExpr.arguments.enumerated() {
            let propName: String
            if let label = arg.label {
                propName = label.text
            } else {
                // Map positional arguments to properties
                switch componentName {
                case "Text": propName = "content"
                case "Button" where index == 0: propName = "title"
                case "Image": propName = "name"
                case "Label" where index == 0: propName = "title"
                case "Toggle" where index == 0: propName = "label"
                case "Stepper" where index == 0: propName = "label"
                case "Picker" where index == 0: propName = "label"
                case "DatePicker" where index == 0: propName = "label"
                case "ColorPicker" where index == 0: propName = "label"
                case "SecureField" where index == 0: propName = "placeholder"
                case "NavigationLink" where index == 0: propName = "label"
                default: propName = "arg\(index)"
                }
            }
                
            // Validate property
            if !context.capabilityRegistry.supportsProperty(propName, on: componentName) {
                context.addDiagnostic("⚠️ Unsupported property '\(propName)' on '\(componentName)'")
            }

            let property = IRProperty(
                name: propName,
                value: exprLowerer.lower(arg.expression)
            )
            properties.append(property)
        }
        
        var children: [IRViewNode] = []
        var statements: [IRStatement] = []

        // Handle trailing closure
        if let trailingClosure = callExpr.trailingClosure {
            for item in trailingClosure.statements {
                if let stmtLowerer = stmtLowerer {
                    let irStmt = stmtLowerer.lowerCodeBlockItem(item)
                    
                    // If the statement is just a view expression, add it as a child
                    if case .expression(let expr) = irStmt, 
                       let childView = lowerIRExpressionToView(expr) {
                        children.append(childView)
                    } else {
                        statements.append(irStmt)
                    }
                }
            }
        }
        
        return IRViewNode(
            componentName: componentName,
            properties: properties,
            modifiers: [],
            children: children,
            statements: statements
        )
    }
    
    private func lowerIRExpressionToView(_ expr: IRExpression) -> IRViewNode? {
        if case .view(let node) = expr {
            return node
        }
        return nil
    }
    
    public func lowerViewExpression(_ exprSyntax: ExprSyntaxProtocol) -> IRViewNode? {
        var baseExpr = exprSyntax
        var modifierStack: [FunctionCallExprSyntax] = []
        
        while let funcCall = baseExpr.as(FunctionCallExprSyntax.self) {
            modifierStack.append(funcCall)
            
            if let nextBase = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
               let base = nextBase.base {
                baseExpr = base
            } else {
                break
            }
        }
        
        guard let baseViewCall = baseExpr.as(FunctionCallExprSyntax.self) else {
            return nil
        }
        
        guard let viewNode = lowerViewCall(baseViewCall) else {
            return nil
        }
        
        for i in stride(from: modifierStack.count - 1, through: 0, by: -1) {
            let modifierCall = modifierStack[i]
            
            if let modifier = modifierLowerer.lower(modifierCall) {
                viewNode.applyModifier(modifier)
            }
        }
        
        return viewNode
    }
    
    private func extractComponentName(_ exprSyntax: ExprSyntaxProtocol) -> String? {
        if let ident = exprSyntax.as(DeclReferenceExprSyntax.self) {
            return ident.baseName.text
        }
        
        if let member = exprSyntax.as(MemberAccessExprSyntax.self) {
            return member.declName.baseName.text
        }
        
        return nil
    }
}
