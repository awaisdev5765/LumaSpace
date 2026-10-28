import SwiftUI

struct BeforeAfterSlider: View {
    let beforeImage: UIImage?
    let afterImage: UIImage?
    var beforeLabel: String = "Before"
    var afterLabel: String = "After"
    @State private var sliderPosition: CGFloat = 0.5
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // After (right side — full width underneath)
                imageView(afterImage, placeholder: "wand.and.stars", label: "After")
                    .frame(width: geo.size.width, height: geo.size.height)

                // Before (left side — clipped to slider position)
                imageView(beforeImage, placeholder: "camera.viewfinder", label: "Before")
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(
                        Rectangle()
                            .path(in: CGRect(x: 0, y: 0,
                                            width: geo.size.width * sliderPosition,
                                            height: geo.size.height))
                    )

                // Divider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .offset(x: geo.size.width * sliderPosition - 1)
                    .shadow(color: .black.opacity(0.3), radius: 4)

                // Handle
                sliderHandle
                    .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)

                // Labels
                HStack {
                    labelPill(beforeLabel)
                    Spacer()
                    labelPill(afterLabel)
                }
                .padding(.horizontal, LumaSpacing.md)
                .padding(.top, LumaSpacing.md)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        // Direct update — no animation during active drag for 1:1 feel
                        sliderPosition = max(0.05, min(0.95, value.location.x / geo.size.width))
                    }
            )
            .accessibilityLabel("Before and after design comparison. Drag to compare.")
            .accessibilityValue("Slider at \(Int(sliderPosition * 100))%")
        }
        .aspectRatio(4/3, contentMode: .fit)
    }

    private var sliderHandle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 44, height: 44)
                .lumaShadow(radius: 8, y: 2, opacity: 0.25)
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.Luma.accent)
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.lumaFast, value: isDragging)
    }

    private func labelPill(_ text: String) -> some View {
        Text(text)
            .font(LumaFont.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, LumaSpacing.sm)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func imageView(_ image: UIImage?, placeholder: String, label: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            ZStack {
                Color(uiColor: .systemGray5)
                VStack(spacing: LumaSpacing.sm) {
                    Image(systemName: placeholder)
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text(label)
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
