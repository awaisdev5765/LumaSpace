import SwiftUI

struct ShoppingView: View {
    let furnitureItems: [FurnitureItem]
    var title: String = "Recommended Furniture"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: FurnitureItem.Category?
    @State private var sortOrder: SortOrder = .relevance
    @State private var searchText = ""
    @State private var selectedItem: FurnitureItem?

    enum SortOrder: String, CaseIterable {
        case relevance = "Relevance"
        case priceLow  = "Price: Low"
        case priceHigh = "Price: High"
    }

    var filtered: [FurnitureItem] {
        var items = furnitureItems
        if let cat = selectedCategory { items = items.filter { $0.category == cat } }
        if !searchText.isEmpty { items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        switch sortOrder {
        case .priceLow:  items.sort { ($0.price ?? 0) < ($1.price ?? 0) }
        case .priceHigh: items.sort { ($0.price ?? 0) > ($1.price ?? 0) }
        case .relevance: break
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            sortBar
            Divider()

            if filtered.isEmpty {
                LumaEmptyState(
                    icon: "cart",
                    title: "No Items",
                    message: "Generate a design concept first to see furniture recommendations."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: LumaSpacing.sm) {
                        ForEach(filtered) { item in
                            ShoppingItemRow(item: item) {
                                selectedItem = item
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, LumaSpacing.xxxl)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search furniture")
        .sheet(item: $selectedItem) { item in
            FurnitureDetailSheet(item: item)
        }
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumaSpacing.sm) {
                LumaChip(text: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(FurnitureItem.Category.allCases, id: \.self) { cat in
                    LumaChip(
                        text: cat.rawValue.capitalized,
                        isSelected: selectedCategory == cat
                    ) { selectedCategory = cat }
                }
                Divider().frame(height: 20)
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) { sortOrder = order }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOrder.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(LumaFont.caption1)
                    .fontWeight(.medium)
                    .padding(.horizontal, LumaSpacing.md)
                    .padding(.vertical, LumaSpacing.xs + 2)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, LumaSpacing.sm)
        }
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: FurnitureItem
    let onTap: () -> Void
    @EnvironmentObject private var appState: AppState

    private var isSaved: Bool { appState.isFurnitureSaved(name: item.name) }

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.light)
            onTap()
        }) {
            HStack(spacing: LumaSpacing.md) {
                // Thumbnail
                ProductImageView(url: item.thumbnailURL, category: item.category)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                    Text(item.name)
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)

                    if let brand = item.brand {
                        Text(brand)
                            .font(LumaFont.caption1)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(String(format: "%.0f", item.dimensions.width * 100))W × \(String(format: "%.0f", item.dimensions.depth * 100))D × \(String(format: "%.0f", item.dimensions.height * 100))H cm")
                        .font(LumaFont.caption2)
                        .foregroundStyle(.tertiary)

                    if !item.colorOptions.isEmpty {
                        HStack(spacing: LumaSpacing.xs) {
                            ForEach(item.colorOptions.prefix(4), id: \.self) { colorName in
                                Circle()
                                    .fill(Color.fromColorName(colorName))
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                                    .accessibilityLabel(colorName)
                            }
                            if item.colorOptions.count > 4 {
                                Text("+\(item.colorOptions.count - 4)")
                                    .font(LumaFont.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: LumaSpacing.sm) {
                    if let price = item.price {
                        Text("$\(Int(price).formatted())")
                            .font(LumaFont.headline)
                            .fontWeight(.bold)
                    }

                    Button {
                        appState.toggleSavedFurniture(name: item.name)
                        LumaHaptics.impact(.light)
                        AnalyticsService.shared.track(
                            isSaved ? .furnitureViewed : .furnitureSaved,
                            properties: ["item": item.name]
                        )
                    } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(isSaved ? .red : .secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Remove from saved" : "Save item")
                }
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .lumaShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.price.map { "$\(Int($0))" } ?? "")")
    }
}

// MARK: - Furniture Detail Sheet

struct FurnitureDetailSheet: View {
    let item: FurnitureItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedColor: String?
    @State private var isPurchased: Bool
    @EnvironmentObject private var appState: AppState

    init(item: FurnitureItem) {
        self.item = item
        self._isPurchased = State(initialValue: item.isPurchased)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    // Large product image
                    ProductImageView(url: item.thumbnailURL, category: item.category)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                        .padding(.horizontal)

                    // Info
                    VStack(alignment: .leading, spacing: LumaSpacing.lg) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name).font(LumaFont.title3)
                                if let brand = item.brand {
                                    Text(brand).font(LumaFont.subhead).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let price = item.price {
                                Text("$\(Int(price).formatted())")
                                    .font(LumaFont.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.Luma.accent)
                            }
                        }

                        // Dimensions
                        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                            Text("Dimensions").font(LumaFont.headline)
                            HStack(spacing: LumaSpacing.lg) {
                                DimBadge(label: "W", value: "\(String(format: "%.0f", item.dimensions.width * 100)) cm")
                                DimBadge(label: "D", value: "\(String(format: "%.0f", item.dimensions.depth * 100)) cm")
                                DimBadge(label: "H", value: "\(String(format: "%.0f", item.dimensions.height * 100)) cm")
                            }
                        }

                        // Colors
                        if !item.colorOptions.isEmpty {
                            VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                                Text("Color Options").font(LumaFont.headline)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: LumaSpacing.sm) {
                                        ForEach(item.colorOptions, id: \.self) { color in
                                            HStack(spacing: LumaSpacing.xs) {
                                                Circle()
                                                    .fill(Color.fromColorName(color))
                                                    .frame(width: 12, height: 12)
                                                    .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                                                Text(color)
                                                    .font(LumaFont.caption1)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, LumaSpacing.md)
                                            .padding(.vertical, LumaSpacing.xs + 2)
                                            .foregroundStyle(selectedColor == color ? .white : .primary)
                                            .background(selectedColor == color ? Color.Luma.accent : Color(uiColor: .tertiarySystemFill))
                                            .clipShape(Capsule())
                                            .onTapGesture {
                                                selectedColor = color
                                                LumaHaptics.selection()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CTAs
                        VStack(spacing: LumaSpacing.md) {
                            let retailerLabel: String = {
                                if let r = item.retailer, !r.isEmpty { return "View on \(r)" }
                                return "Find This Item"
                            }()
                            LumaPrimaryButton(retailerLabel, icon: "arrow.up.right", hint: "Opens the retailer website") {
                                let destination: URL? = item.affiliateShoppingURL()
                                    ?? item.affiliateURL
                                if let url = destination {
                                    UIApplication.shared.open(url)
                                } else {
                                    let query = (item.name + " furniture")
                                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    if let url = URL(string: "https://www.google.com/search?tbm=shop&q=\(query)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                AnalyticsService.shared.track(.furnitureAffiliateTap,
                                    properties: ["item": item.name, "retailer": item.retailer ?? "web"])
                            }

                            // Mark as purchased — updates the room digital twin
                            Button {
                                isPurchased.toggle()
                                markPurchased(isPurchased)
                                LumaHaptics.notification(isPurchased ? .success : .warning)
                            } label: {
                                Label(
                                    isPurchased ? "Purchased ✓" : "Mark as Purchased",
                                    systemImage: isPurchased ? "checkmark.circle.fill" : "bag.badge.plus"
                                )
                                .font(LumaFont.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .foregroundStyle(isPurchased ? .white : Color.Luma.accent)
                                .background(isPurchased
                                    ? Color.green
                                    : Color.Luma.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                                .overlay {
                                    if !isPurchased {
                                        RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                                            .strokeBorder(Color.Luma.accent.opacity(0.3), lineWidth: 1.5)
                                    }
                                }
                                .animation(reduceMotion ? .none : .lumaSpring, value: isPurchased)
                            }
                            .buttonStyle(.plain)

                            LumaSecondaryButton("Place in AR", icon: "arkit", hint: "Opens AR view to place this item in your room") {
                                NotificationCenter.default.post(name: .launchAR, object: nil)
                                dismiss()
                            }

                            LumaSecondaryButton("Find in Catalog", icon: "magnifyingglass", hint: "Search for similar items in the furniture catalog") {
                                NotificationCenter.default.post(name: .launchCatalogSearch, object: item.name)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .navigationTitle(item.category.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// Persists the purchased state back to every project room that contains this item.
    private func markPurchased(_ purchased: Bool) {
        let store = ProjectStore.shared
        for var project in store.projects {
            var changed = false
            for ri in project.rooms.indices {
                for fi in project.rooms[ri].furnitureItems.indices
                where project.rooms[ri].furnitureItems[fi].id == item.id {
                    project.rooms[ri].furnitureItems[fi].isPurchased = purchased
                    changed = true
                }
            }
            if changed { store.update(project) }
        }
        AnalyticsService.shared.track(
            purchased ? .furnitureSaved : .furnitureViewed,
            properties: ["item": item.name, "action": purchased ? "purchased" : "unpurchased"]
        )
    }
}

struct DimBadge: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(LumaFont.caption2).foregroundStyle(.secondary)
            Text(value).font(LumaFont.subhead).fontWeight(.semibold)
        }
        .frame(minWidth: 60)
        .padding(.vertical, LumaSpacing.sm)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
    }
}
