//
//  IRProgram.swift
//  swiftjs
//
//  Top-level intermediate representation of a complete program
//

import Foundation

/// The complete lowered program consisting of one or more files
public class IRProgram: BaseIRNode {
    public let files: [IRFile]
    
    public init(
        files: [IRFile] = [],
        sourceLocation: SourceLocation? = nil
    ) {
        self.files = files
        super.init(sourceLocation: sourceLocation)
    }
}
