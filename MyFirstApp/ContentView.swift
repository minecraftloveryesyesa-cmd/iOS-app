import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 56))

            Text("Hello, iPhone!")
                .font(.largeTitle)
                .bold()

            Text("Built with GitHub Actions")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}