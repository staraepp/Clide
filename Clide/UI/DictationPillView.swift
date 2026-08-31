import SwiftUI

/// Bare-bones visual for the floating dictation pill. Deliberately simple for the
/// 0.1 sacred-path prototype — full animation/motion polish comes once the
/// underlying pipeline (shortcut → capture → transcribe → insert) is reliable.
struct DictationPillView: View {
    let state: PillState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)

            if !state.message.isEmpty {
                Text(state.message)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(.black.opacity(0.85))
        )
        .animation(.easeOut(duration: 0.15), value: state)
    }
}

#Preview {
    VStack(spacing: 12) {
        DictationPillView(state: .listening)
        DictationPillView(state: .transcribing)
        DictationPillView(state: .inserted)
        DictationPillView(state: .copiedToClipboard)
        DictationPillView(state: .secureFieldBlocked)
        DictationPillView(state: .error("Model unavailable"))
    }
    .padding()
}
