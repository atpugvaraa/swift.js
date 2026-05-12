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
    public var output: String = ""
    public var isClientComponent: Bool = false
    public var usedComponents: Set<String> = []
    public var usedModifiers: Set<String> = []
    
    public var stateVariables: Set<String> = []
    public let capabilityRegistry = CapabilityRegistry()
    
    internal var handlers: [String: ViewHandler] = [:]
    internal var modifierHandlers: [String: ModifierHandler] = [:]
    internal let genericHandler = GenericViewHandler()

    public init() {
        registerDefaultHandlers()
    }
    
    /// Legacy string-based transpilation
    public func transpile(_ source: String) -> String {
        return transpileSemantic(source)
    }

    /// New semantic IR-based compilation
    public func transpileSemantic(_ source: String) -> String {
        let sourceFile = Parser.parse(source: source)
        
        // 1. Semantic Analysis
        let analyzer = SemanticAnalyzer()
        analyzer.analyze(sourceFile)
        
        // 2. Lowering to IR
        let lowerer = FileLowerer()
        let irFile = lowerer.lower(sourceFile)
        
        // 3. Emission to TypeScript
        let emitter = FileEmitter()
        return emitter.emit(irFile)
    }
    
    private func registerDefaultHandlers() {
        // Register legacy handlers
        handlers["Text"] = TextHandler()
        handlers["Button"] = ButtonHandler()
        handlers["VStack"] = VStackHandler()
        handlers["HStack"] = HStackHandler()
        handlers["ZStack"] = ZStackHandler()
        handlers["ScrollView"] = ScrollViewHandler()
        handlers["Spacer"] = SpacerHandler()
        handlers["Image"] = ImageHandler()
        handlers["TextField"] = TextFieldHandler()
        
        modifierHandlers["padding"] = PaddingHandler()
        modifierHandlers["background"] = BackgroundHandler()
        modifierHandlers["opacity"] = OpacityHandler()
        modifierHandlers["blendMode"] = BlendModeHandler()
        modifierHandlers["foregroundStyle"] = ForegroundStyleHandler()
        modifierHandlers["font"] = FontHandler()
        modifierHandlers["fontWeight"] = FontWeightHandler()
        
        // Layout Modifiers
        modifierHandlers["frame"] = FrameHandler()
        modifierHandlers["ignoresSafeArea"] = IgnoresSafeAreaHandler()
        
        // Event Modifiers
        modifierHandlers["onTapGesture"] = OnTapGestureHandler()
        modifierHandlers["onHover"] = OnHoverHandler()
        
        // Animation Modifiers
        modifierHandlers["rotationEffect"] = RotationEffectHandler()
        modifierHandlers["scaleEffect"] = ScaleEffectHandler()
        modifierHandlers["animation"] = AnimationHandler()
        
        // Use new rich registry defaults
        capabilityRegistry.registerDefaults()
    }
}
