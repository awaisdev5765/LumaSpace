import SwiftUI

struct ColorPaletteView: View {
    let selectedStyle: DesignStyle
    @State private var copiedHex: String?

    var body: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.xxl) {
                Text("Color Palette")
                    .font(LumaFont.title2)
                    .padding(.top)

                HStack(spacing: 0) {
                    ForEach(selectedStyle.palette.indices, id: \.self) { i in
                        VStack(spacing: LumaSpacing.xs) {
                            selectedStyle.palette[i]
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .overlay(alignment: .bottom) {
                                    if let hex = copiedHex, hex == selectedStyle.palette[i].hexString {
                                        Text("Copied!")
                                            .font(LumaFont.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                            .padding(.bottom, 4)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                }
                            Text(["Primary", "Secondary", "Accent", "Neutral"][safe: i] ?? "Color")
                                .font(LumaFont.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .onTapGesture {
                            let hex = selectedStyle.palette[i].hexString
                            UIPasteboard.general.string = hex
                            withAnimation(.lumaFast) { copiedHex = hex }
                            LumaHaptics.notification(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.lumaFast) { copiedHex = nil }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                .padding(.horizontal)

                Text("Tap a swatch to copy its hex code")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    LumaSectionHeader(title: "Suggestions")
                    ColorSuggestionRow(name: "Walls", colors: [selectedStyle.palette[safe: 0] ?? .white])
                    ColorSuggestionRow(name: "Accent Wall", colors: [selectedStyle.palette[safe: 2] ?? .gray])
                    ColorSuggestionRow(
                        name: "Furniture",
                        colors: [
                            selectedStyle.palette[safe: 1] ?? .gray,
                            selectedStyle.palette[safe: 3] ?? .gray
                        ]
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, LumaSpacing.xxxl)
        }
    }
}

struct ColorSuggestionRow: View {
    let name: String
    let colors: [Color]
    @State private var copiedHex: String?

    var body: some View {
        HStack {
            Text(name).font(LumaFont.subhead)
            Spacer()
            HStack(spacing: LumaSpacing.xs) {
                ForEach(colors.indices, id: \.self) { i in
                    colors[i]
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(.separator, lineWidth: 0.5) }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .accessibilityLabel("\(name) color \(i + 1), \(colors[i].hexString). Long press to copy.")
                        .onLongPressGesture {
                            let hex = colors[i].hexString
                            UIPasteboard.general.string = hex
                            copiedHex = hex
                            LumaHaptics.notification(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedHex = nil }
                        }
                }
            }
        }
        .padding(LumaSpacing.md)
        .lumaCard(padding: LumaSpacing.md)
    }
}
