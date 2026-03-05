import SwiftUI

struct ContextModeSwitcherView: View {
    let selectedMode: ContextMode
    let onModeChanged: (ContextMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContextMode.allCases) { mode in
                Button {
                    onModeChanged(mode)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedMode == mode
                            ? mode.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .foregroundStyle(selectedMode == mode ? mode.accentColor : .secondary)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
