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
    
    public var stateVariables: Set<String> = []
    
    internal var handlers: [String: ViewHandler] = [:]
    internal var modifierHandlers: [String: ModifierHandler] = [:]
    internal let genericHandler = GenericViewHandler()

    public init() {
        registerDefaultHandlers()
    }
    
    public func transpile(_ source: String) -> String {
        output = ""
        isClientComponent = false
        usedComponents = []
        stateVariables = []
        
        let sourceFile = Parser.parse(source: source)
        let visitor = Visitor(transpiler: self)
        visitor.walk(sourceFile)
        
        // Header Generation
        var header = ""
        if isClientComponent {
            header += "'use client';\n"
        }
        header += "import React, { useState } from 'react';\n"
        
        if !usedComponents.isEmpty {
            let sortedComponents = usedComponents.sorted().joined(separator: ", ")
            header += "import { \(sortedComponents) } from '@/swiftui';\n\n"
        } else {
            header += "import * as SwiftUI from '@/swiftui';\n\n"
        }
        
        return header + output
    }
    
    private func registerDefaultHandlers() {
        handlers["Text"] = TextHandler()
        handlers["Button"] = ButtonHandler()
        modifierHandlers["padding"] = PaddingHandler()
    }
}
