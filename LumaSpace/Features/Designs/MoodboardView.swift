import SwiftUI
import PhotosUI

struct MoodboardView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var items: [MoodboardItem] = []
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var showPhotoPicker = false
    @State private var showAddColor = false
    @State private var newColorHex = "#1A7A6E"

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.lg) {
                addBar

                if items.isEmpty {
                    LumaEmptyState(
                        icon: "photo.stack",
                        title: "Empty Moodboard",
                        message: "Add photos, colors, and textures to inspire your design.",
                        actionLabel: "Add Photos"
                    ) { showPhotoPicker = true }
                } else {
                    moodGrid
                }
            }
            .padding()
            .padding(.bottom, LumaSpacing.xxxl)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: selectedItems) { _, picked in
            Task {
                for item in picked {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let mItem = MoodboardItem(type: .image, title: "Photo", imageData: data)
                        withAnimation(reduceMotion ? .none : .lumaSpring) { items.insert(mItem, at: 0) }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddColor) {
            AddColorSheet { hex in
                let item = MoodboardItem(type: .color, title: "Color", colorHex: hex)
                withAnimation(reduceMotion ? .none : .lumaSpring) { items.insert(item, at: 0) }
            }
        }
    }

    // MARK: - Add Bar

    private var addBar: some View {
        HStack(spacing: LumaSpacing.md) {
            Button {
                showPhotoPicker = true
                LumaHaptics.impact(.light)
            } label: {
                Label("Photo", systemImage: "photo.badge.plus")
                    .font(LumaFont.subhead)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.Luma.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                    .foregroundStyle(Color.Luma.accent)
            }
            .buttonStyle(.plain)

            Button {
                showAddColor = true
                LumaHaptics.impact(.light)
            } label: {
                Label("Color", systemImage: "eyedropper")
                    .font(LumaFont.subhead)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.Luma.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                    .foregroundStyle(Color.Luma.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Grid

    private var moodGrid: some View {
        LazyVGrid(columns: columns, spacing: LumaSpacing.sm) {
            ForEach(items) { item in
                MoodboardCell(item: item) {
                    withAnimation(reduceMotion ? .none : .lumaSpring) { items.removeAll { $0.id == item.id } }
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : .lumaSpring, value: items.map(\.id))
    }
}

// MARK: - Cell

struct MoodboardCell: View {
    let item: MoodboardItem
    let onDelete: () -> Void
    @State private var showActions = false

    var body: some View {
        ZStack {
            Group {
                if item.type == .color, let hex = item.colorHex {
                    Color(hex: hex)
                } else if let data = item.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(uiColor: .systemFill)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            .lumaShadow(radius: 6, y: 2, opacity: 0.1)

            if item.type == .color, let hex = item.colorHex {
                VStack {
                    Spacer()
                    Text(hex.uppercased())
                        .font(LumaFont.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(.bottom, LumaSpacing.xs)
                }
            }
        }
        .contextMenu {
            Button("Remove", systemImage: "trash", role: .destructive) {
                LumaHaptics.impact(.medium)
                onDelete()
            }
        }
        .accessibilityLabel(item.type == .color ? "Color \(item.colorHex ?? "")" : item.title)
    }
}

// MARK: - Add Color Sheet

struct AddColorSheet: View {
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var red: Double = 0.1
    @State private var green: Double = 0.5
    @State private var blue: Double = 0.4

    var hex: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    var body: some View {
        NavigationStack {
            VStack(spacing: LumaSpacing.xxl) {
                RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                    .fill(color)
                    .frame(height: 160)
                    .overlay {
                        Text(hex.uppercased())
                            .font(LumaFont.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }

                VStack(spacing: LumaSpacing.md) {
                    colorSlider(label: "Red", value: $red, tint: .red)
                    colorSlider(label: "Green", value: $green, tint: .green)
                    colorSlider(label: "Blue", value: $blue, tint: .blue)
                }
            }
            .padding()
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(hex)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func colorSlider(label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack {
            Text(label).font(LumaFont.subhead).frame(width: 50, alignment: .leading)
            Slider(value: value).tint(tint)
            Text("\(Int(value.wrappedValue * 255))")
                .font(LumaFont.caption1)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

