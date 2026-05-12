import SwiftUI

struct ToggleView: View {
    @State var isOn = false
    
    var body: some View {
        VStack {
            if isOn {
                Text("It is ON")
                    .foregroundColor(.green)
            } else {
                Text("It is OFF")
                    .foregroundColor(.red)
            }
            
            Button("Toggle") {
                isOn.toggle()
            }
        }
    }
}
