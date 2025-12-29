//
//  Test.swift
//  swiftjs
//
//  Created by Aarav Gupta on 29/12/25.
//

import SwiftUI

struct CounterView: View {
    @State var count = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Count: \(count)")
            Button(title: "Increment", action: count + 1)
            TextField(text: $count)
        }
    }
}
