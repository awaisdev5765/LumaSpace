import SwiftUI

// MARK: - Explore View
// Shown as a standalone section — accessible from Home tab and a dedicated "Explore" tab.
// Contains: seasonal picks, style quiz, trending catalog products, curated style packs.

struct ExploreView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreService
    @StateObject private var catalog = FurnitureCatalogService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showStyleQuiz = false
    @State private var showRoomBuilder = false
    @State private var showCatalog = false
    @State private var selectedProduct: CatalogProduct?
    @State private var selectedStyle: DesignStyle?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    seasonalHero
                        .padding(.horizontal)

                    styleQuizCard
                        .padding(.horizontal)

                    trendingSection

                    roomBuilderCard
                        .padding(.horizontal)

                    stylePacksPreview

                    categoriesGrid
                        .padding(.horizontal)
                }
                .padding(.vertical, LumaSpacing.base)
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showStyleQuiz) {
            StyleQuizView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showRoomBuilder) {
            RoomBuilderView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationBackground(Color(uiColor: .systemGroupedBackground))
        }
        .sheet(item: $selectedProduct) { product in
            CatalogProductDetailView(product: product)
                .environmentObject(catalog)
                .environmentObject(appState)
        }
        .sheet(item: $selectedStyle) { style in
            StyleInspirationSheet(style: style)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCatalog) {
            FurnitureCatalogView()
                .environmentObject(appState)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAR)) { _ in
            selectedProduct = nil
            showCatalog = false
            dismiss()
        }
    }

    // MARK: - Seasonal Hero

    private var seasonalHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: currentSeasonGradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)

            // Pattern overlay
            Canvas { ctx, size in
                for i in 0..<8 {
                    let x = CGFloat(i) * size.width / 7
                    for j in 0..<6 {
                        let y = CGFloat(j) * size.height / 5
                        let r: CGFloat = CGFloat.random(in: 2...6)
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)),
                                 with: .color(.white.opacity(0.05)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                Text(currentSeasonBadge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())

                Text(currentSeasonTitle)
                    .font(LumaFont.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(currentSeasonSubtitle)
                    .font(LumaFont.subhead)
                    .foregroundStyle(.white.opacity(0.75))

                Button {
                    showCatalog = true
                    LumaHaptics.impact(.light)
                } label: {
                    Text("Shop the Collection →")
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, LumaSpacing.md)
                        .padding(.vertical, LumaSpacing.sm)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, LumaSpacing.xs)
            }
            .padding(LumaSpacing.base)
        }
        .lumaShadow()
    }

    // MARK: - Style Quiz Card

    private var styleQuizCard: some View {
        Button {
            showStyleQuiz = true
            LumaHaptics.impact(.medium)
        } label: {
            HStack(spacing: LumaSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "0F0C29"), Color(hex: "302B63")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Text("🎨")
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Discover Your Style")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("5-question quiz · 20 styles matched")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.Luma.accent)
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .lumaShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trending Section

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                LumaSectionHeader(title: "Trending Products")
                Spacer()
                Button("See All") {
                    showCatalog = true
                }
                .font(LumaFont.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Luma.accent)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.md) {
                    ForEach(catalog.trendingProducts.prefix(10)) { product in
                        TrendingProductCard(
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
        }
    }

    // MARK: - Room Builder Card

    private var roomBuilderCard: some View {
        Button {
            showRoomBuilder = true
            LumaHaptics.impact(.medium)
        } label: {
            HStack(spacing: LumaSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.Luma.navy, Color(hex: "26D0CE")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "square.dashed")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: LumaSpacing.xs) {
                        Text("Room Planner")
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("No LiDAR needed")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.Luma.accent)
                            .clipShape(Capsule())
                    }
                    Text("Draw floor plans on any iPhone, place furniture to scale")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "26D0CE"))
            }
            .padding(LumaSpacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .lumaShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style Packs Preview

    private var stylePacksPreview: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            HStack {
                LumaSectionHeader(title: "Shop by Style")
                Spacer()
                Button("All Styles") {
                    showCatalog = true
                }
                .font(LumaFont.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Luma.accent)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.md) {
                    ForEach([DesignStyle.japandi, .scandinavian, .modernLuxury, .coastal, .bohemian, .midCentury, .industrial, .farmhouse], id: \.self) { style in
                        StyleTileCard(style: style) {
                            selectedStyle = style
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            LumaSectionHeader(title: "Browse by Category")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: LumaSpacing.sm
            ) {
                ForEach(FurnitureItem.Category.allCases, id: \.self) { cat in
                    CategoryTile(category: cat) {
                        catalog.selectedCategory = cat
                        showCatalog = true
                    }
                }
            }
        }
    }

    // MARK: - Seasonal Data

    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }

    private var currentSeasonGradient: [Color] {
        switch currentMonth {
        case 3...5:  return [Color(hex: "2D6A4F"), Color(hex: "52B788")]    // Spring
        case 6...8:  return [Color(hex: "0096C7"), Color(hex: "48CAE4")]    // Summer
        case 9...11: return [Color(hex: "BC4749"), Color(hex: "E76F51")]    // Fall
        default:     return [Color(hex: "1B2A4A"), Color(hex: "2B4D7E")]   // Winter
        }
    }

    private var currentSeasonBadge: String {
        switch currentMonth {
        case 3...5:  return "🌸 SPRING COLLECTION"
        case 6...8:  return "☀️ SUMMER EDIT"
        case 9...11: return "🍂 AUTUMN REFRESH"
        default:     return "❄️ WINTER WARMTH"
        }
    }

    private var currentSeasonTitle: String {
        switch currentMonth {
        case 3...5:  return "Freshen Up Your Space"
        case 6...8:  return "Light, Airy Summer Vibes"
        case 9...11: return "Cozy Autumn Interiors"
        default:     return "Warm Up Your Home"
        }
    }

    private var currentSeasonSubtitle: String {
        switch currentMonth {
        case 3...5:  return "Biophilic designs, fresh greens, natural light"
        case 6...8:  return "Coastal hues, linen, rattan, and organic textures"
        case 9...11: return "Earthy tones, velvet, warm wood, layered rugs"
        default:     return "Deep neutrals, plush textures, moody lighting"
        }
    }
}

// MARK: - Trending Product Card

struct TrendingProductCard: View {
    let product: CatalogProduct
    var isWishlisted: Bool
    let onTap: () -> Void
    let onWishlist: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                            .fill(Color.Luma.accent.opacity(0.1))
                            .frame(width: 148, height: 120)
                        Image(systemName: product.category.icon)
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(Color.Luma.accent.opacity(0.45))
                            .symbolRenderingMode(.hierarchical)
                    }

                    Button(action: onWishlist) {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(isWishlisted ? .red : .secondary)
                            .padding(LumaSpacing.xs)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(width: 140)
                    HStack {
                        Text(product.brand)
                            .font(LumaFont.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("$\(Int(product.price))")
                            .font(LumaFont.caption1)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.Luma.accent)
                    }
                }
                .padding(.horizontal, LumaSpacing.sm)
                .padding(.vertical, LumaSpacing.sm)
            }
            .frame(width: 148)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .lumaShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Style Tile Card

struct StyleTileCard: View {
    let style: DesignStyle
    let action: () -> Void

    var body: some View {
        Button(action: { LumaHaptics.impact(.light); action() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(style.palette.prefix(4).indices, id: \.self) { i in
                        style.palette[i]
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                    }
                }
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: LumaRadius.lg, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: LumaRadius.lg
                ))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(style.emoji)
                        Text(style.rawValue)
                            .font(LumaFont.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, LumaSpacing.sm)
                .padding(.vertical, LumaSpacing.sm)
            }
            .frame(width: 130)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.rawValue) style")
    }
}

// MARK: - Category Tile

struct CategoryTile: View {
    let category: FurnitureItem.Category
    let action: () -> Void

    var body: some View {
        Button(action: { LumaHaptics.impact(.light); action() }) {
            VStack(spacing: LumaSpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.Luma.accent)
                    .frame(width: 52, height: 52)
                    .background(Color.Luma.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                Text(category.rawValue.capitalized)
                    .font(LumaFont.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LumaSpacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.rawValue.capitalized)
    }
}
