import SwiftUI

// Displays all past AI-generated designs for a given room, grouped by date.
struct DesignHistoryView: View {
    let room: Room
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var selectedConcept: DesignConcept?

    private var allDesigns: [DesignConcept] {
        // Find the project that owns this room, then return all its designs.
        // Fall back to all designs across all projects if the room can't be matched.
        let owningProject = projectStore.projects.first(where: { project in
            project.rooms.contains(where: { $0.id == room.id })
        })
        return (owningProject?.designs ?? projectStore.projects.flatMap(\.designs))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var grouped: [(String, [DesignConcept])] {
        Dictionary(grouping: allDesigns) { concept in
            concept.createdAt.formatted(.dateTime.month(.wide).year())
        }
        .sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if allDesigns.isEmpty {
                LumaEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No Design History",
                    message: "Generate AI designs for this room and they'll appear here.",
                    actionLabel: nil
                )
            } else {
                List {
                    ForEach(grouped, id: \.0) { month, concepts in
                        Section(month) {
                            ForEach(concepts) { concept in
                                Button {
                                    selectedConcept = concept
                                } label: {
                                    DesignHistoryRow(concept: concept)
                                }
                                .buttonStyle(LumaListRowButtonStyle())
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Design History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedConcept) { concept in
            DesignDetailView(concept: concept)
        }
    }
}

struct DesignHistoryRow: View {
    let concept: DesignConcept

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            // Thumbnail or gradient swatch
            ZStack {
                if let data = concept.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: concept.style.palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(concept.style.emoji + " " + concept.style.rawValue)
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                    if concept.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                Text(concept.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                Text("Est. $\(Int(concept.estimatedCost).formatted())")
                    .font(LumaFont.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, LumaSpacing.xs)
    }
}
