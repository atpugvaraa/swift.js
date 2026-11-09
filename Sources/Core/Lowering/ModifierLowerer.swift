import Foundation
import SwiftSyntax

/// Converts SwiftUI modifiers to React style effects for @swiftuijs/ui.
/// Each supported modifier checks its arguments; any other form is reported, never guessed.
public class ModifierLowerer {
    private let context: LoweringContext
    private let exprLowerer: ExpressionLowerer

    /// Modifiers with at least one supported form. Single source for the capability registry.
    public static let supportedModifiers: Set<String> = [
        "padding", "font", "bold", "fontWeight", "foregroundColor", "foregroundStyle",
        "background", "opacity", "cornerRadius", "frame",
    ]

    public init(context: LoweringContext, exprLowerer: ExpressionLowerer) {
        self.context = context
        self.exprLowerer = exprLowerer
    }

    public func lower(_ callExpr: FunctionCallExprSyntax) -> IRModifier? {
        guard let memberAccess = callExpr.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        let modifierName = memberAccess.declName.baseName.text
        let modifier = IRModifier(name: modifierName, arguments: [])

        guard Self.supportedModifiers.contains(modifierName) else {
            context.addDiagnostic("not yet supported: modifier .\(modifierName)", at: memberAccess.period)
            return modifier
        }
        guard callExpr.trailingClosure == nil, let styles = styles(modifierName, Array(callExpr.arguments)) else {
            let arguments = callExpr.arguments.trimmedDescription
            context.addDiagnostic("not yet supported: .\(modifierName)(\(arguments))", at: memberAccess.period)
            return modifier
        }

        modifier.effects = styles.map { .style(key: $0.key, value: $0.value) }
        return modifier
    }

    /// CSS declarations for a supported modifier form, or nil when this form is not supported.
    private func styles(_ name: String, _ args: [LabeledExprSyntax]) -> [(key: String, value: IRExpression)]? {
        let only = args.count == 1 && args[0].label == nil ? args[0].expression : nil

        switch name {
        case "padding":
            // SwiftUI's default padding is 16pt on every edge.
            if args.isEmpty { return [("padding", .numberLiteral(16))] }
            if let n = only.flatMap(number) { return [("padding", .numberLiteral(n))] }

        case "font":
            if let style = only.flatMap(implicitMember), let token = Self.fontSizeTokens[style] {
                return [("fontSize", .stringLiteral("var(--sw-font-size-\(token))"))]
            }

        case "bold":
            if args.isEmpty { return [("fontWeight", .numberLiteral(700))] }

        case "fontWeight":
            if let weight = only.flatMap(implicitMember), let n = Self.fontWeights[weight] {
                return [("fontWeight", .numberLiteral(n))]
            }

        case "foregroundColor", "foregroundStyle":
            if let css = only.flatMap(color) { return [("color", .stringLiteral(css))] }

        case "background":
            if let css = only.flatMap(color) { return [("background", .stringLiteral(css))] }

        case "opacity":
            if let n = only.flatMap(number) { return [("opacity", .numberLiteral(n))] }

        case "cornerRadius":
            if let n = only.flatMap(number) { return [("borderRadius", .numberLiteral(n))] }

        case "frame":
            // .frame(width:height:) and min/max variants; .infinity fills the parent.
            let keys = ["width": "width", "height": "height", "minWidth": "minWidth",
                        "minHeight": "minHeight", "maxWidth": "maxWidth", "maxHeight": "maxHeight"]
            var result: [(key: String, value: IRExpression)] = []
            for arg in args {
                guard let label = arg.label?.text, let key = keys[label] else { return nil }
                if let n = number(arg.expression) {
                    result.append((key, .numberLiteral(n)))
                } else if implicitMember(arg.expression) == "infinity", label.hasPrefix("max") {
                    result.append((label == "maxWidth" ? "width" : "height", .stringLiteral("100%")))
                } else {
                    return nil
                }
            }
            // SwiftUI frames centre their content by default.
            if !result.isEmpty {
                return result + [("display", .stringLiteral("flex")), ("justifyContent", .stringLiteral("center")),
                                 ("alignItems", .stringLiteral("center"))]
            }

        default:
            break
        }
        return nil
    }

    // MARK: - Argument readers (syntax, not IR, so unsupported forms are never half-lowered)

    private func number(_ expr: ExprSyntax) -> Double? {
        if let int = expr.as(IntegerLiteralExprSyntax.self) { return Double(int.literal.text) }
        if let float = expr.as(FloatLiteralExprSyntax.self) { return Double(float.literal.text) }
        return nil
    }

    /// `.name` with no base, e.g. `.largeTitle`.
    private func implicitMember(_ expr: ExprSyntax) -> String? {
        guard let member = expr.as(MemberAccessExprSyntax.self), member.base == nil else { return nil }
        return member.declName.baseName.text
    }

    /// `.red` or `Color.red` as a CSS color.
    private func color(_ expr: ExprSyntax) -> String? {
        guard let member = expr.as(MemberAccessExprSyntax.self) else { return nil }
        if let base = member.base {
            guard base.as(DeclReferenceExprSyntax.self)?.baseName.text == "Color" else { return nil }
        }
        return Self.colors[member.declName.baseName.text]
    }

    // MARK: - Tables

    /// SwiftUI Font.TextStyle -> @swiftuijs/ui `--sw-font-size-*` suffix.
    private static let fontSizeTokens: [String: String] = [
        "largeTitle": "large-title", "title": "title-1", "title2": "title-2", "title3": "title-3",
        "headline": "headline", "body": "body", "callout": "callout", "subheadline": "subheadline",
        "footnote": "footnote", "caption": "caption-1", "caption2": "caption-2",
    ]

    private static let fontWeights: [String: Double] = [
        "ultraLight": 100, "thin": 200, "light": 300, "regular": 400, "medium": 500,
        "semibold": 600, "bold": 700, "heavy": 800, "black": 900,
    ]

    /// SwiftUI colors -> @swiftuijs/ui tokens (follow light/dark) or Apple's light-mode values.
    // ponytail: hex values don't adapt to dark mode; swap for tokens if swiftuijs adds them.
    private static let colors: [String: String] = [
        "primary": "var(--sw-color-label-primary)", "secondary": "var(--sw-color-label-secondary)",
        "accentColor": "var(--sw-color-accent)",
        "red": "var(--sw-color-red)", "orange": "var(--sw-color-orange)", "green": "var(--sw-color-green)",
        "blue": "var(--sw-color-blue)", "gray": "var(--sw-color-gray)", "white": "var(--sw-color-white)",
        "black": "#000000", "clear": "transparent",
        "yellow": "#FFCC00", "mint": "#00C7BE", "teal": "#30B0C7", "cyan": "#32ADE6",
        "indigo": "#5856D6", "purple": "#AF52DE", "pink": "#FF2D55", "brown": "#A2845E",
    ]
}
