import SwiftUI

struct ConceptComparisonView: View {
    let conceptA: DesignConcept
    let conceptB: DesignConcept
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LumaSpacing.xxl) {
                    if let imgA = conceptA.previewImage, let imgB = conceptB.previewImage {
                        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                            LumaSectionHeader(title: "Design Comparison")
                            BeforeAfterSlider(
                                beforeImage: imgA,
                                afterImage: imgB,
                                beforeLabel: String(conceptA.style.rawValue.prefix(12)),
                                afterLabel: String(conceptB.style.rawValue.prefix(12))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: LumaSpacing.sm) {
                        paletteCard(concept: conceptA)
                        paletteCard(concept: conceptB)
                    }
                    .padding(.horizontal)

                    HStack(spacing: LumaSpacing.sm) {
                        costCard(concept: conceptA)
                        costCard(concept: conceptB)
                    }
                    .padding(.horizontal)

                    VStack(spacing: LumaSpacing.md) {
                        comparisonRow(labelA: conceptA.style.rawValue, labelB: conceptB.style.rawValue, title: "Style")
                        comparisonRow(labelA: conceptA.description, labelB: conceptB.description, title: "Description")
                        comparisonRow(
                            labelA: "\(conceptA.furnitureSuggestions.count) items",
                            labelB: "\(conceptB.furnitureSuggestions.count) items",
                            title: "Furniture"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, LumaSpacing.xxxl)
            }
            .navigationTitle("Compare Designs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func paletteCard(concept: DesignConcept) -> some View {
        VStack(spacing: LumaSpacing.xs) {
            Text("\(concept.style.emoji) \(concept.style.rawValue)")
                .font(LumaFont.caption1)
                .fontWeight(.semibold)
                .lineLimit(1)

            if let image = concept.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            } else {
                HStack(spacing: 0) {
                    ForEach(concept.style.palette.indices, id: \.self) { i in
                        concept.style.palette[i]
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }

    private func costCard(concept: DesignConcept) -> some View {
        VStack(spacing: 4) {
            Text("Est. Cost")
                .font(LumaFont.caption2)
                .foregroundStyle(.secondary)
            Text("$\(Int(concept.estimatedCost).formatted())")
                .font(LumaFont.title3)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(LumaSpacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }

    private func comparisonRow(labelA: String, labelB: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: LumaSpacing.xs) {
            Text(title)
                .font(LumaFont.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(spacing: LumaSpacing.sm) {
                Text(labelA)
                    .font(LumaFont.caption1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LumaSpacing.sm)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
                Text(labelB)
                    .font(LumaFont.caption1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LumaSpacing.sm)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
            }
        }
    }
}
