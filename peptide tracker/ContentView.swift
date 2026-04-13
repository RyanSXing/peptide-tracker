import SwiftUI

struct ContentView: View {
    let userId: String

    var body: some View {
        Text("Hello, world — user: \(userId)")
    }
}

#Preview {
    ContentView(userId: "preview")
}
