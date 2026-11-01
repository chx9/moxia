import SwiftUI

/// 工具栏中的强调色圆点，点开后提供几组精选色与自定义取色
struct AccentPicker: View {
    @Bindable var state: AppState
    @State private var isPresented = false

    private static let presets: [(name: String, hex: String)] = [
        ("松绿", "#1f7a6b"), ("黛蓝", "#2f6fde"), ("靛青", "#3d4f8f"), ("朱砂", "#a8402f"),
        ("胭脂", "#c2416b"), ("琥珀", "#e07b2a"), ("藤紫", "#7a5bbd"), ("石墨", "#3c3c3c"),
    ]

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(state.accentColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(.black.opacity(0.1)))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(HeaderButtonStyle())
        .help("强调色")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 14) {
                Text("强调色")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 10), count: 4), spacing: 10) {
                    ForEach(Self.presets, id: \.hex) { preset in
                        swatch(preset.hex, name: preset.name)
                    }
                }

                Divider()

                HStack {
                    ColorPicker("自定义", selection: $state.accentColor, supportsOpacity: false)
                        .font(.system(size: 12))
                    Spacer()
                    Button("跟随主题") { state.accentHex = nil }
                        .font(.system(size: 12))
                        .disabled(state.accentHex == nil)
                }
            }
            .padding(16)
            .frame(width: 184)
        }
    }

    private func swatch(_ hex: String, name: String) -> some View {
        let selected = state.accentHex?.lowercased() == hex
        return Button {
            state.accentHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 22, height: 22)
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Color.primary.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help(name)
    }
}
