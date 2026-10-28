import SwiftUI

// MARK: - Furniture Catalog View (main Shop tab)

struct FurnitureCatalogView: View {
    @StateObject private var catalog = FurnitureCatalogService.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedProduct: CatalogProduct?
    @State private var showFilters = false
    @State private var showRoomBuilder = false
    @State private var showWishlist = false
    @State private var activeSection: CatalogSection = .browse
    @State private var isGridLayout = true

    enum CatalogSection: String, CaseIterable {
        case browse   = "Browse"
        case trending = "Trending"
        case styles   = "By Style"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker
                    .padding(.horizontal)
                    .padding(.vertical, LumaSpacing.sm)
                Divider()
                content
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Shop Furniture")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $catalog.searchText, prompt: "Search furniture…")
            .toolbar { toolbarContent }
        }
        .sheet(item: $selectedProduct) { product in
            CatalogProductDetailView(product: product)
                .environmentObject(catalog)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFilters) {
            CatalogFiltersView(catalog: catalog)
        }
        .sheet(isPresented: $showRoomBuilder) {
            RoomBuilderView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationBackground(Color(uiColor: .systemGroupedBackground))
        }
        .sheet(isPresented: $showWishlist) {
            CatalogWishlistView(catalog: catalog)
                .environmentObject(appState)
        }
        .onChange(of: catalog.searchText) { _, q in
            if !q.isEmpty { activeSection = .browse }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAR)) { _ in
            selectedProduct = nil
            dismiss()
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker("Section", selection: $activeSection) {
            ForEach(CatalogSection.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: activeSection) { _, _ in LumaHaptics.selection() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            switch activeSection {
            case .browse:   browseContent
            case .trending: trendingContent
            case .styles:   stylePacksContent
            }
        }
        .transition(.opacity)
        .id(activeSection)
        .animation(reduceMotion ? .none : .lumaSpring, value: activeSection)
    }

    // MARK: - Browse

    private var browseContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Category filter chips
                categoryChips
                    .padding(.vertical, LumaSpacing.sm)

                // Active filters summary
                if hasActiveFilters {
                    activeFiltersBanner
                        .padding(.horizontal)
                        .padding(.bottom, LumaSpacing.sm)
                }

                // Results
                Section {
                    if catalog.filteredProducts.isEmpty {
                        ContentUnavailableView.search(text: catalog.searchText.isEmpty ? "No matches" : catalog.searchText)
                            .padding(.top, LumaSpacing.xxxl)
                    } else {
                        if isGridLayout {
                            productGrid(catalog.filteredProducts)
                        } else {
                            productList(catalog.filteredProducts)
                        }
                    }
                } header: {
                    HStack {
                        Text("\(catalog.filteredProducts.count) Products")
                            .font(LumaFont.caption1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation(reduceMotion ? .none : .lumaFast) { isGridLayout.toggle() }
                            LumaHaptics.selection()
                        } label: {
                            Image(systemName: isGridLayout ? "list.bullet" : "square.grid.2x2")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, LumaSpacing.xs)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .padding(.bottom, LumaSpacing.xxxl)
        }
    }

    // MARK: - Trending

    private var trendingContent: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.xxl) {
                // Hero banner
                trendingHero
                    .padding(.horizontal)

                // Trending products
                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    LumaSectionHeader(title: "Trending Now")
                        .padding(.horizontal)
                    productGrid(catalog.trendingProducts)
                }

                // New arrivals
                if !catalog.newArrivals.isEmpty {
                    VStack(alignment: .leading, spacing: LumaSpacing.md) {
                        LumaSectionHeader(title: "New Arrivals")
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: LumaSpacing.md) {
                                ForEach(catalog.newArrivals.prefix(8)) { product in
                                    CompactProductCard(
                                        product: product,
                                        onTap: {
                                            selectedProduct = product
                                            catalog.recordView(product)
                                        },
                                        onWishlist: {
                                            catalog.toggleWishlist(product)
                                            LumaHaptics.impact(.light)
                                        },
                                        wishlisted: catalog.isWishlisted(product)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Recently viewed
                if !catalog.recentlyViewed.isEmpty {
                    VStack(alignment: .leading, spacing: LumaSpacing.md) {
                        LumaSectionHeader(title: "Recently Viewed")
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: LumaSpacing.md) {
                                ForEach(catalog.recentlyViewed.prefix(6)) { product in
                                    CompactProductCard(
                                        product: product,
                                        onTap: {
                                            selectedProduct = product
                                            catalog.recordView(product)
                                        },
                                        onWishlist: {
                                            catalog.toggleWishlist(product)
                                        },
                                        wishlisted: catalog.isWishlisted(product)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, LumaSpacing.base)
            .padding(.bottom, LumaSpacing.xxxl)
        }
    }

    // MARK: - Style Packs

    private var stylePacksContent: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.xxl) {
                stylePackIntro
                    .padding(.horizontal)

                ForEach(catalog.stylePacks) { pack in
                    StylePackSection(pack: pack, catalog: catalog) { product in
                        selectedProduct = product
                        catalog.recordView(product)
                    }
                }
            }
            .padding(.vertical, LumaSpacing.base)
            .padding(.bottom, LumaSpacing.xxxl)
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumaSpacing.xs) {
                LumaChip(text: "All", isSelected: catalog.selectedCategory == nil) {
                    catalog.selectedCategory = nil
                }
                ForEach(FurnitureItem.Category.allCases, id: \.self) { cat in
                    LumaChip(
                        text: "\(categoryEmoji(cat)) \(cat.rawValue.capitalized)",
                        isSelected: catalog.selectedCategory == cat
                    ) {
                        catalog.selectedCategory = catalog.selectedCategory == cat ? nil : cat
                        LumaHaptics.selection()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryEmoji(_ cat: FurnitureItem.Category) -> String {
        switch cat {
        case .sofa:     return "🛋️"
        case .chair:    return "🪑"
        case .table:    return "🪵"
        case .bed:      return "🛏️"
        case .desk:     return "🖥️"
        case .storage:  return "🗄️"
        case .lighting: return "💡"
        case .rug:      return "🪺"
        case .decor:    return "🏺"
        case .plant:    return "🪴"
        }
    }

    // MARK: - Active Filters Banner

    private var hasActiveFilters: Bool {
        catalog.selectedPriceRange != nil || catalog.selectedRetailer != nil || catalog.selectedStyle != nil
    }

    private var activeFiltersBanner: some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.Luma.accent)
                .font(.subheadline)
            Text(activeFilterDescription)
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Clear") {
                catalog.clearFilters()
                LumaHaptics.impact(.light)
            }
            .font(LumaFont.caption1)
            .fontWeight(.semibold)
            .foregroundStyle(Color.Luma.accent)
        }
        .padding(LumaSpacing.sm)
        .background(Color.Luma.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
    }

    private var activeFilterDescription: String {
        var parts: [String] = []
        if let pr = catalog.selectedPriceRange { parts.append(pr.rawValue) }
        if let ret = catalog.selectedRetailer { parts.append(ret) }
        if let sty = catalog.selectedStyle { parts.append(sty.rawValue) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Product Grid / List

    private func productGrid(_ products: [CatalogProduct]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: LumaSpacing.md
        ) {
            ForEach(products) { product in
                ProductGridCard(
                    product: product,
                    isWishlisted: catalog.isWishlisted(product)
                ) {
                    selectedProduct = product
                    catalog.recordView(product)
                    LumaHaptics.impact(.light)
                } onWishlist: {
                    catalog.toggleWishlist(product)
                    LumaHaptics.impact(.light)
                }
            }
        }
        .padding(.horizontal)
    }

    private func productList(_ products: [CatalogProduct]) -> some View {
        LazyVStack(spacing: LumaSpacing.sm) {
            ForEach(products) { product in
                CatalogProductRow(
                    product: product,
                    isWishlisted: catalog.isWishlisted(product)
                ) {
                    selectedProduct = product
                    catalog.recordView(product)
                } onWishlist: {
                    catalog.toggleWishlist(product)
                    LumaHaptics.impact(.light)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Trending Hero

    private var trendingHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.Luma.navy, Color(hex: "26D0CE")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))

            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                Text("Trending Now")
                    .font(LumaFont.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("The \(catalog.trendingProducts.count) most-saved pieces this week")
                    .font(LumaFont.subhead)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(LumaSpacing.base)
        }
        .lumaShadow()
    }

    // MARK: - Style Pack Intro

    private var stylePackIntro: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
            Text("Shop by Style")
                .font(LumaFont.title2)
            Text("Curated furniture bundles to complete each design aesthetic")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: LumaSpacing.md) {
                // Wishlist
                Button {
                    showWishlist = true
                    LumaHaptics.impact(.light)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "heart")
                            .font(.subheadline)
                        if !catalog.wishlistProducts.isEmpty {
                            Text("\(catalog.wishlistProducts.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .accessibilityLabel("Wishlist")

                // Room Builder
                Button {
                    showRoomBuilder = true
                    LumaHaptics.impact(.medium)
                } label: {
                    Image(systemName: "square.dashed")
                }
                .accessibilityLabel("Room Planner")

                // Filters
                Button {
                    showFilters = true
                    LumaHaptics.impact(.light)
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(hasActiveFilters ? Color.Luma.accent : .primary)
                }
                .accessibilityLabel("Filters")
            }
        }
    }
}

// MARK: - Product Grid Card

struct ProductGridCard: View {
    let product: CatalogProduct
    var isWishlisted: Bool
    let onTap: () -> Void
    let onWishlist: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Product image area
                ZStack(alignment: .topTrailing) {
                    productImageArea
                        .frame(height: 140)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: LumaRadius.lg, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0, topTrailingRadius: LumaRadius.lg
                        ))

                    // Badges
                    VStack(alignment: .trailing, spacing: LumaSpacing.xs) {
                        if product.isOnSale, let pct = product.discountPercent {
                            Text("-\(pct)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                        if product.isNew {
                            Text("NEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.Luma.accent)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(LumaSpacing.xs)

                    // Wishlist button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: onWishlist) {
                                Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                    .font(.subheadline)
                                    .foregroundStyle(isWishlisted ? .red : .white)
                                    .padding(LumaSpacing.xs + 2)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(LumaSpacing.xs)
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                    Text(product.name)
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(product.brand)
                        .font(LumaFont.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        if let orig = product.originalPrice {
                            Text("$\(Int(orig))")
                                .font(LumaFont.caption2)
                                .strikethrough()
                                .foregroundStyle(.tertiary)
                        }
                        Text("$\(Int(product.price))")
                            .font(LumaFont.caption1)
                            .fontWeight(.bold)
                            .foregroundStyle(product.isOnSale ? .red : Color.Luma.accent)
                        Spacer()
                        StarRating(rating: product.rating, size: 8)
                    }
                }
                .padding(LumaSpacing.sm)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .lumaShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.name) by \(product.brand), $\(Int(product.price))")
    }

    private var productImageArea: some View {
        ProductImageView(url: product.imageURL, category: product.category)
    }
}

// MARK: - Compact Product Card (horizontal scroll)

struct CompactProductCard: View {
    let product: CatalogProduct
    let onTap: () -> Void
    let onWishlist: () -> Void
    var wishlisted: Bool

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ProductImageView(url: product.imageURL, category: product.category)
                        .frame(width: 120, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                    Button(action: onWishlist) {
                        Image(systemName: wishlisted ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(wishlisted ? .red : .secondary)
                            .padding(LumaSpacing.xs)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(LumaFont.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(width: 110)
                    Text("$\(Int(product.price))")
                        .font(LumaFont.caption2)
                        .foregroundStyle(Color.Luma.accent)
                }
                .padding(.horizontal, LumaSpacing.xs)
                .padding(.vertical, LumaSpacing.xs)
            }
            .frame(width: 120)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Catalog Product Row (list view)

struct CatalogProductRow: View {
    let product: CatalogProduct
    var isWishlisted: Bool
    let onTap: () -> Void
    let onWishlist: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LumaSpacing.md) {
                // Thumbnail
                ProductImageView(url: product.imageURL, category: product.category)
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                    Text(product.name)
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(product.brand)
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                    HStack(spacing: LumaSpacing.xs) {
                        StarRating(rating: product.rating, size: 9)
                        Text("(\(product.reviewCount.formatted()))")
                            .font(LumaFont.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: LumaSpacing.xs) {
                    HStack(spacing: 4) {
                        if let orig = product.originalPrice {
                            Text("$\(Int(orig))")
                                .font(LumaFont.caption2)
                                .strikethrough()
                                .foregroundStyle(.tertiary)
                        }
                        Text("$\(Int(product.price))")
                            .font(LumaFont.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(product.isOnSale ? .red : .primary)
                    }
                    Button(action: onWishlist) {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .foregroundStyle(isWishlisted ? .red : .secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Style Pack Section

struct StylePackSection: View {
    let pack: StylePack
    let catalog: FurnitureCatalogService
    let onTap: (CatalogProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: LumaSpacing.xs) {
                        Text(pack.style.emoji)
                        Text(pack.style.rawValue)
                            .font(LumaFont.headline)
                            .fontWeight(.semibold)
                    }
                    Text(pack.description)
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("From $\(Int(pack.items.min(by: { $0.price < $1.price })?.price ?? 0))")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                    Text("Bundle est. $\(Int(pack.totalPrice))")
                        .font(LumaFont.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)

            // Palette strip
            HStack(spacing: 0) {
                ForEach(pack.style.palette.indices, id: \.self) { i in
                    pack.style.palette[i].frame(maxWidth: .infinity).frame(height: 6)
                }
            }
            .clipShape(Capsule())
            .padding(.horizontal)

            // Items scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.md) {
                    ForEach(pack.items) { product in
                        CompactProductCard(
                            product: product,
                            onTap: { onTap(product) },
                            onWishlist: {
                                catalog.toggleWishlist(product)
                                LumaHaptics.impact(.light)
                            },
                            wishlisted: catalog.isWishlisted(product)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Catalog Filters View

struct CatalogFiltersView: View {
    @ObservedObject var catalog: FurnitureCatalogService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Price Range") {
                    ForEach(CatalogProduct.PriceRange.allCases, id: \.self) { range in
                        HStack {
                            Label(range.rawValue, systemImage: range.icon)
                            Spacer()
                            if catalog.selectedPriceRange == range {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.Luma.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            catalog.selectedPriceRange = catalog.selectedPriceRange == range ? nil : range
                            LumaHaptics.selection()
                        }
                    }
                }

                Section("Design Style") {
                    ForEach(DesignStyle.allCases) { style in
                        HStack {
                            Text("\(style.emoji) \(style.rawValue)")
                            Spacer()
                            if catalog.selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.Luma.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            catalog.selectedStyle = catalog.selectedStyle == style ? nil : style
                            LumaHaptics.selection()
                        }
                    }
                }

                Section("Retailer") {
                    ForEach(catalog.allRetailers, id: \.self) { retailer in
                        HStack {
                            Text(retailer)
                            Spacer()
                            if catalog.selectedRetailer == retailer {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.Luma.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            catalog.selectedRetailer = catalog.selectedRetailer == retailer ? nil : retailer
                            LumaHaptics.selection()
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        catalog.clearFilters()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Wishlist View

struct CatalogWishlistView: View {
    @ObservedObject var catalog: FurnitureCatalogService
    @EnvironmentObject private var appState: AppState
    @State private var selectedProduct: CatalogProduct?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if catalog.wishlistProducts.isEmpty {
                    LumaEmptyState(
                        icon: "heart",
                        title: "Your Wishlist is Empty",
                        message: "Tap the heart icon on any product to save it here."
                    )
                } else {
                    List {
                        ForEach(catalog.wishlistProducts) { product in
                            CatalogProductRow(
                                product: product,
                                isWishlisted: true,
                                onTap: { selectedProduct = product },
                                onWishlist: {
                                    catalog.toggleWishlist(product)
                                    LumaHaptics.impact(.light)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: LumaSpacing.xs, leading: LumaSpacing.base, bottom: LumaSpacing.xs, trailing: LumaSpacing.base))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Wishlist (\(catalog.wishlistProducts.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .sheet(item: $selectedProduct) { product in
            CatalogProductDetailView(product: product)
                .environmentObject(catalog)
                .environmentObject(appState)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Product Detail View

struct CatalogProductDetailView: View {
    let product: CatalogProduct
    @EnvironmentObject private var catalog: FurnitureCatalogService
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: String?
    @State private var showPriceAlertSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    // Large product image
                    ProductImageView(url: product.imageURL, category: product.category)
                        .frame(height: 260)
                    .overlay(alignment: .topTrailing) {
                        if product.isNew {
                            Text("NEW")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.Luma.accent)
                                .clipShape(Capsule())
                                .padding(LumaSpacing.md)
                        }
                    }
                    .clipShape(Rectangle())

                    VStack(alignment: .leading, spacing: LumaSpacing.xl) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                                Text(product.name)
                                    .font(LumaFont.title3)
                                Text(product.brand)
                                    .font(LumaFont.subhead)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: LumaSpacing.xs) {
                                    StarRating(rating: product.rating, size: 11)
                                    Text("(\(product.reviewCount.formatted()))")
                                        .font(LumaFont.caption1)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                if let orig = product.originalPrice {
                                    Text("$\(Int(orig))")
                                        .font(LumaFont.subhead)
                                        .strikethrough()
                                        .foregroundStyle(.tertiary)
                                }
                                Text("$\(Int(product.price))")
                                    .font(LumaFont.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(product.isOnSale ? .red : Color.Luma.accent)
                            }
                        }

                        // Description
                        Text(product.productDescription)
                            .font(LumaFont.body)
                            .foregroundStyle(.secondary)

                        // Dimensions
                        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                            Text("Dimensions")
                                .font(LumaFont.headline)
                            HStack(spacing: LumaSpacing.lg) {
                                DimBadge(label: "W", value: "\(Int(product.dimensions.width * 100)) cm")
                                DimBadge(label: "D", value: "\(Int(product.dimensions.depth * 100)) cm")
                                DimBadge(label: "H", value: "\(Int(product.dimensions.height * 100)) cm")
                            }
                        }

                        // Compatible styles
                        if !product.compatibleStyles.isEmpty {
                            VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                                Text("Works With")
                                    .font(LumaFont.headline)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: LumaSpacing.xs) {
                                        ForEach(product.compatibleStyles, id: \.self) { style in
                                            Text("\(style.emoji) \(style.rawValue)")
                                                .font(LumaFont.caption1)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, LumaSpacing.md)
                                                .padding(.vertical, LumaSpacing.xs + 2)
                                                .background(Color(uiColor: .tertiarySystemFill))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        // Colors
                        if !product.colorOptions.isEmpty {
                            VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                                Text("Colors")
                                    .font(LumaFont.headline)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: LumaSpacing.sm) {
                                        ForEach(product.colorOptions, id: \.self) { color in
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
                            LumaPrimaryButton("Shop on \(product.retailer)", icon: "arrow.up.right") {
                                if let url = product.affiliateShoppingURL() {
                                    UIApplication.shared.open(url)
                                }
                                AnalyticsService.shared.track(.furnitureAffiliateTap,
                                    properties: ["item": product.name, "retailer": product.retailer])
                            }

                            // Wishlist
                            let wishlisted = catalog.isWishlisted(product)
                            Button {
                                catalog.toggleWishlist(product)
                                LumaHaptics.notification(wishlisted ? .warning : .success)
                            } label: {
                                Label(
                                    wishlisted ? "Saved to Wishlist" : "Save to Wishlist",
                                    systemImage: wishlisted ? "heart.fill" : "heart"
                                )
                                .font(LumaFont.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .foregroundStyle(wishlisted ? .white : Color.Luma.accent)
                                .background(wishlisted ? .red : Color.Luma.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                                .overlay {
                                    if !wishlisted {
                                        RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                                            .strokeBorder(Color.Luma.accent.opacity(0.3), lineWidth: 1.5)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .animation(.lumaSpring, value: wishlisted)

                            // Price alert
                            let hasAlert = catalog.hasPriceAlert(for: product)
                            Button {
                                if hasAlert {
                                    catalog.removePriceAlert(for: product)
                                    LumaHaptics.impact(.light)
                                } else {
                                    showPriceAlertSheet = true
                                    LumaHaptics.impact(.light)
                                }
                            } label: {
                                Label(
                                    hasAlert ? "Alert Set: $\(Int(catalog.targetPrice(for: product) ?? 0))" : "Set Price Alert",
                                    systemImage: hasAlert ? "bell.fill" : "bell"
                                )
                                .font(LumaFont.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .foregroundStyle(hasAlert ? .white : .primary)
                                .background(hasAlert ? Color.orange : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                                .animation(.lumaFast, value: hasAlert)
                            }
                            .buttonStyle(.plain)

                            // See in AR
                            LumaSecondaryButton("Visualize in AR", icon: "arkit") {
                                NotificationCenter.default.post(name: .launchAR, object: nil)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showPriceAlertSheet) {
            PriceAlertSheet(product: product)
                .environmentObject(catalog)
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Price Alert Sheet

struct PriceAlertSheet: View {
    let product: CatalogProduct
    @EnvironmentObject private var catalog: FurnitureCatalogService
    @Environment(\.dismiss) private var dismiss
    @State private var targetPrice: Double

    init(product: CatalogProduct) {
        self.product = product
        _targetPrice = State(initialValue: product.price * 0.9)
    }

    private let presets: [(String, Double)] = [
        ("10% off", 0.9),
        ("20% off", 0.8),
        ("30% off", 0.7),
        ("50% off", 0.5),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: LumaSpacing.xxl) {
                VStack(spacing: LumaSpacing.sm) {
                    Text(product.name)
                        .font(LumaFont.headline)
                    HStack(spacing: LumaSpacing.xs) {
                        Text("Current price:")
                            .font(LumaFont.subhead)
                            .foregroundStyle(.secondary)
                        Text("$\(Int(product.price))")
                            .font(LumaFont.subhead)
                            .fontWeight(.bold)
                    }
                }
                .padding(.top)

                VStack(spacing: LumaSpacing.md) {
                    Text("Notify me when price drops to:")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)

                    Text("$\(Int(targetPrice))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.Luma.accent)
                        .contentTransition(.numericText())
                        .animation(.lumaFast, value: targetPrice)

                    Slider(
                        value: $targetPrice,
                        in: product.price * 0.3...product.price * 0.99,
                        step: 5
                    )
                    .tint(Color.Luma.accent)
                    .padding(.horizontal)
                }

                HStack(spacing: LumaSpacing.sm) {
                    ForEach(presets, id: \.0) { label, factor in
                        Button {
                            withAnimation(.lumaFast) { targetPrice = (product.price * factor / 5).rounded() * 5 }
                            LumaHaptics.selection()
                        } label: {
                            Text(label)
                                .font(LumaFont.caption1)
                                .fontWeight(.semibold)
                                .padding(.horizontal, LumaSpacing.md)
                                .padding(.vertical, LumaSpacing.xs + 2)
                                .background(
                                    abs(targetPrice - product.price * factor) < 6
                                        ? Color.Luma.accent
                                        : Color(uiColor: .secondarySystemGroupedBackground)
                                )
                                .foregroundStyle(
                                    abs(targetPrice - product.price * factor) < 6 ? .white : .primary
                                )
                                .clipShape(Capsule())
                                .animation(.lumaFast, value: targetPrice)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                LumaPrimaryButton("Set Alert for $\(Int(targetPrice))", icon: "bell.badge") {
                    catalog.setPriceAlert(for: product, targetPrice: targetPrice)
                    LumaHaptics.notification(.success)
                    dismiss()
                }
                .padding(.horizontal)
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .navigationTitle("Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Star Rating

struct StarRating: View {
    let rating: Double
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: starName(for: i))
                    .font(.system(size: size))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func starName(for index: Int) -> String {
        let threshold = Double(index) + 1.0
        if rating >= threshold { return "star.fill" }
        if rating >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}
