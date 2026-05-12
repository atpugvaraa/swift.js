import SwiftUI

struct Counter: View {
    @State var count: Int = 0
    
    var body: some View {
        VStack {
            Text("Count is \(count)")
            Button("Increment") {
                count += 1
            }
            .padding()
        }
    }
}
