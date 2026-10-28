import SwiftUI

// MARK: - Style Quiz
// 5 visual questions → recommends top 3 design styles.

struct StyleQuizView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentQuestion = 0
    @State private var answers: [Int: Int] = [:]  // questionIndex: answerIndex
    @State private var showResults = false
    @State private var resultStyles: [DesignStyle] = []

    private let questions: [QuizQuestion] = QuizQuestion.all

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if showResults {
                    resultsView
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                } else {
                    questionView
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        .id(currentQuestion)
                }
            }
            .navigationTitle("Style Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                if !showResults {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(currentQuestion + 1)/\(questions.count)")
                            .font(LumaFont.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal)
                .padding(.top, LumaSpacing.md)

            ScrollView {
                VStack(spacing: LumaSpacing.xl) {
                    // Question
                    VStack(spacing: LumaSpacing.sm) {
                        Text(questions[currentQuestion].category)
                            .font(LumaFont.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text(questions[currentQuestion].text)
                            .font(LumaFont.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, LumaSpacing.xxl)

                    // Answers
                    VStack(spacing: LumaSpacing.md) {
                        ForEach(questions[currentQuestion].options.indices, id: \.self) { i in
                            let option = questions[currentQuestion].options[i]
                            let isSelected = answers[currentQuestion] == i

                            Button {
                                selectAnswer(i)
                            } label: {
                                HStack(spacing: LumaSpacing.md) {
                                    Text(option.emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(isSelected ? .white : .white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.text)
                                            .font(LumaFont.subhead)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(isSelected ? Color(hex: "302B63") : .white)
                                        if !option.detail.isEmpty {
                                            Text(option.detail)
                                                .font(LumaFont.caption1)
                                                .foregroundStyle(isSelected ? Color(hex: "302B63").opacity(0.7) : .white.opacity(0.5))
                                        }
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color(hex: "302B63"))
                                    }
                                }
                                .padding(LumaSpacing.md)
                                .background(isSelected ? .white : .white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                                        .strokeBorder(isSelected ? .clear : .white.opacity(0.15), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .animation(reduceMotion ? .none : .lumaFast, value: isSelected)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, LumaSpacing.xxxl)
                }
            }

            // Next / Finish button
            bottomNavigation
                .padding(.horizontal)
                .padding(.bottom, LumaSpacing.base)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: LumaSpacing.xs) {
            ForEach(0..<questions.count, id: \.self) { i in
                Capsule()
                    .fill(i <= currentQuestion ? .white : .white.opacity(0.2))
                    .frame(height: 3)
                    .animation(reduceMotion ? .none : .lumaSpring, value: currentQuestion)
            }
        }
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        let hasAnswer = answers[currentQuestion] != nil
        let isLast = currentQuestion == questions.count - 1

        return Button {
            if isLast {
                computeResults()
            } else {
                withAnimation(reduceMotion ? .none : .lumaSpring) { currentQuestion += 1 }
                LumaHaptics.impact(.light)
            }
        } label: {
            Text(isLast ? "See My Styles" : "Next")
                .font(LumaFont.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(hasAnswer ? Color(hex: "0F0C29") : .white.opacity(0.4))
                .background(hasAnswer ? .white : .white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!hasAnswer)
        .animation(reduceMotion ? .none : .lumaFast, value: hasAnswer)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: LumaSpacing.xxl) {
                // Hero
                VStack(spacing: LumaSpacing.sm) {
                    Text("Your Style DNA")
                        .font(LumaFont.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Based on your answers, these styles match your personality")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, LumaSpacing.xxl)
                .padding(.horizontal)

                // Top 3 styles
                VStack(spacing: LumaSpacing.md) {
                    ForEach(resultStyles.prefix(3).indices, id: \.self) { i in
                        let style = resultStyles[i]
                        ResultStyleCard(style: style, rank: i + 1)
                    }
                }
                .padding(.horizontal)

                // Other matching styles
                if resultStyles.count > 3 {
                    VStack(alignment: .leading, spacing: LumaSpacing.md) {
                        Text("Also Compatible")
                            .font(LumaFont.headline)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: LumaSpacing.sm) {
                                ForEach(resultStyles.dropFirst(3).prefix(5), id: \.self) { style in
                                    Text("\(style.emoji) \(style.rawValue)")
                                        .font(LumaFont.caption1)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, LumaSpacing.md)
                                        .padding(.vertical, LumaSpacing.sm)
                                        .background(.white.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // CTA
                VStack(spacing: LumaSpacing.md) {
                    Button {
                        appState.pendingDesignStyles = Set(resultStyles.prefix(3))
                        appState.activeTab = .designs
                        dismiss()
                        LumaHaptics.notification(.success)
                    } label: {
                        Label("Generate Designs with My Styles", systemImage: "wand.and.stars")
                            .font(LumaFont.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(Color(hex: "0F0C29"))
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Retake
                        withAnimation(reduceMotion ? .none : .lumaSpring) {
                            currentQuestion = 0
                            answers = [:]
                            resultStyles = []
                            showResults = false
                        }
                        LumaHaptics.impact(.light)
                    } label: {
                        Text("Retake Quiz")
                            .font(LumaFont.subhead)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, LumaSpacing.xxxl)
            }
        }
    }

    // MARK: - Logic

    private func selectAnswer(_ index: Int) {
        answers[currentQuestion] = index
        LumaHaptics.impact(.medium)

        // Auto-advance after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if currentQuestion < questions.count - 1 {
                withAnimation(reduceMotion ? .none : .lumaSpring) { currentQuestion += 1 }
                LumaHaptics.impact(.light)
            }
        }
    }

    private func computeResults() {
        // Build score map for each style based on answer weights
        var scores: [DesignStyle: Double] = Dictionary(uniqueKeysWithValues: DesignStyle.allCases.map { ($0, 0.0) })

        for (qIdx, answerIdx) in answers {
            guard qIdx < questions.count else { continue }
            let q = questions[qIdx]
            guard answerIdx < q.options.count else { continue }
            let weights = q.options[answerIdx].weights
            for (style, weight) in weights {
                scores[style, default: 0] += weight
            }
        }

        resultStyles = scores
            .sorted { $0.value > $1.value }
            .map(\.key)

        withAnimation(reduceMotion ? .none : .lumaSpring) { showResults = true }
        LumaHaptics.notification(.success)
    }
}

// MARK: - Result Style Card

struct ResultStyleCard: View {
    let style: DesignStyle
    let rank: Int

    private var medalEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            // Palette strip
            VStack(spacing: 0) {
                ForEach(style.palette.indices, id: \.self) { i in
                    style.palette[i].frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 48)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                HStack(spacing: LumaSpacing.xs) {
                    Text(medalEmoji)
                    Text(style.rawValue)
                        .font(LumaFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Text(style.description)
                    .font(LumaFont.caption1)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer()
            Text(style.emoji)
                .font(.title)
        }
        .padding(LumaSpacing.md)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                .strokeBorder(rank == 1 ? Color.Luma.gold.opacity(0.6) : .white.opacity(0.1), lineWidth: rank == 1 ? 1.5 : 0.5)
        }
    }
}

// MARK: - Quiz Data

struct QuizQuestion {
    let category: String
    let text: String
    let options: [QuizOption]

    static let all: [QuizQuestion] = [
        QuizQuestion(
            category: "Mood",
            text: "How should your home feel when you walk in?",
            options: [
                QuizOption(emoji: "🌿", text: "Calm & serene", detail: "A peaceful retreat from the world",
                    weights: [.japandi: 3, .scandinavian: 2, .minimalist: 2, .wabiSabi: 2, .organicModern: 1]),
                QuizOption(emoji: "✨", text: "Exciting & vibrant", detail: "Every corner has something to discover",
                    weights: [.maximalist: 3, .bohemian: 2, .artDeco: 2, .grandmillennial: 1]),
                QuizOption(emoji: "🏡", text: "Warm & cozy", detail: "Like a hug the moment you step inside",
                    weights: [.farmhouse: 3, .coastal: 2, .bohemian: 1, .midCentury: 1]),
                QuizOption(emoji: "💎", text: "Sophisticated & luxe", detail: "Refined and impressive",
                    weights: [.modernLuxury: 3, .artDeco: 2, .contemporary: 1, .nordicNoir: 1]),
            ]
        ),
        QuizQuestion(
            category: "Palette",
            text: "Which color story speaks to you?",
            options: [
                QuizOption(emoji: "🌾", text: "Warm neutrals", detail: "Beige, sand, warm white, honey oak",
                    weights: [.japandi: 2, .farmhouse: 2, .wabiSabi: 2, .organicModern: 1, .scandinavian: 1]),
                QuizOption(emoji: "🌊", text: "Cool & coastal", detail: "Ocean blue, white, sea glass, sandy linen",
                    weights: [.coastal: 3, .scandinavian: 2, .minimalist: 1, .contemporary: 1]),
                QuizOption(emoji: "🌑", text: "Dark & moody", detail: "Charcoal, navy, forest, matte black",
                    weights: [.nordicNoir: 3, .industrial: 2, .modernLuxury: 2, .artDeco: 1]),
                QuizOption(emoji: "🎨", text: "Bold & rich", detail: "Deep jewel tones, mixed patterns, layered color",
                    weights: [.maximalist: 3, .bohemian: 2, .grandmillennial: 2, .artDeco: 1]),
            ]
        ),
        QuizQuestion(
            category: "Materials",
            text: "What materials make a home feel right?",
            options: [
                QuizOption(emoji: "🪵", text: "Natural & organic", detail: "Wood, linen, rattan, stone, cotton",
                    weights: [.japandi: 3, .farmhouse: 2, .biophilic: 3, .organicModern: 2, .wabiSabi: 2]),
                QuizOption(emoji: "⚙️", text: "Industrial edge", detail: "Steel, concrete, exposed brick, leather",
                    weights: [.industrial: 3, .nordicNoir: 2, .contemporary: 1, .artDeco: 1]),
                QuizOption(emoji: "💫", text: "Luxurious textures", detail: "Velvet, marble, brass, silk, mirrored surfaces",
                    weights: [.modernLuxury: 3, .artDeco: 3, .grandmillennial: 1, .maximalist: 1]),
                QuizOption(emoji: "🌿", text: "Plants & natural life", detail: "Living walls, terracotta, earthy ceramics",
                    weights: [.biophilic: 3, .tropical: 2, .bohemian: 2, .mediterranean: 2, .organicModern: 1]),
            ]
        ),
        QuizQuestion(
            category: "Space",
            text: "How do you like your space organized?",
            options: [
                QuizOption(emoji: "⬜", text: "Less is more", detail: "Every item earns its place — breathing room matters",
                    weights: [.minimalist: 3, .japandi: 2, .scandinavian: 2, .contemporary: 1]),
                QuizOption(emoji: "📚", text: "Curated collections", detail: "Books, art, objects — thoughtfully arranged",
                    weights: [.midCentury: 2, .grandmillennial: 2, .bohemian: 1, .artDeco: 1]),
                QuizOption(emoji: "🏺", text: "Layered & full", detail: "Textured, pattern-on-pattern, lived-in richness",
                    weights: [.maximalist: 3, .bohemian: 2, .grandmillennial: 2, .farmhouse: 1]),
                QuizOption(emoji: "🔄", text: "Flexible & functional", detail: "Everything has purpose, storage everywhere",
                    weights: [.contemporary: 2, .scandinavian: 2, .farmhouse: 1, .minimalist: 1]),
            ]
        ),
        QuizQuestion(
            category: "Era",
            text: "Which design era resonates most?",
            options: [
                QuizOption(emoji: "🏯", text: "Timeless Eastern", detail: "Zen, wabi-sabi, Japanese craft traditions",
                    weights: [.japandi: 3, .wabiSabi: 3, .biophilic: 1, .japandiTwo: 2]),
                QuizOption(emoji: "🕰️", text: "Retro & nostalgic", detail: "1950s–70s optimism, bold shapes, warm wood tones",
                    weights: [.midCentury: 3, .farmhouse: 1, .artDeco: 1, .bohemian: 1]),
                QuizOption(emoji: "🔷", text: "Modern & now", detail: "Clean, current, uncluttered, future-forward",
                    weights: [.contemporary: 3, .minimalist: 2, .nordicNoir: 1, .modernLuxury: 1]),
                QuizOption(emoji: "🌴", text: "Relaxed & global", detail: "Coastal, Mediterranean, tropical, worldly warmth",
                    weights: [.coastal: 2, .tropical: 3, .mediterranean: 2, .bohemian: 1]),
            ]
        ),
    ]
}

struct QuizOption {
    let emoji: String
    let text: String
    let detail: String
    let weights: [DesignStyle: Double]
}
