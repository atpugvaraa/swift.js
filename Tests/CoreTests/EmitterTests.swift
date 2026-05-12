import XCTest
@testable import Core

final class EmitterTests: XCTestCase {
    func testFileEmitterRendersComponentAndClientHeader() {
        let state = IRStateVariable(name: "count", initialValue: .numberLiteral(0), type: "Int")
        let text = IRViewNode(
            componentName: "Text",
            properties: [IRProperty(name: "content", value: .stringLiteral("Hello"))]
        )
        let component = IRComponent(name: "Counter", stateVariables: [state], body: text)
        let file = IRFile(
            imports: [IRImport(items: ["SwiftUI"], module: "SwiftUI")],
            components: [component]
        )
        
        let emitter = FileEmitter()
        let output = emitter.emit(file)
        
        XCTAssertTrue(output.contains("'use client';"))
        XCTAssertTrue(output.contains("import { useState } from 'react';"))
        XCTAssertTrue(output.contains("export const Counter = () => {"))
        XCTAssertTrue(output.contains("useState(0)"))
        XCTAssertTrue(output.contains("<Text"))
    }
    
    func testProgramEmitterJoinsFiles() {
        let file = IRFile()
        let program = IRProgram(files: [file, file])
        let emitter = ProgramEmitter()
        
        let output = emitter.emit(program)
        XCTAssertTrue(output.contains("\n\n"))
    }
}
