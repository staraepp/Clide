import SwiftUI

/// Wraps the browser for presentation as a sheet from Settings or the dashboard.
struct ModelBrowserSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ModelBrowserView()
            Divider()
            HStack {
                Text("Accuracy and speed are estimates from each model's published benchmarks. Hardware Fit is calculated for this Mac.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
    }
}
