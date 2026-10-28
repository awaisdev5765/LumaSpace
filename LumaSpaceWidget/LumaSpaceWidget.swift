import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct ProjectEntry: TimelineEntry {
    let date: Date
    let projectName: String
    let roomCount: Int
    let lastDesignStyle: String?
    let score: Int?
    let relevance: TimelineEntryRelevance?
}

// MARK: - Provider

struct LumaProjectProvider: TimelineProvider {
    typealias Entry = ProjectEntry

    func placeholder(in context: Context) -> ProjectEntry {
        ProjectEntry(
            date: .now,
            projectName: "Living Room Refresh",
            roomCount: 2,
            lastDesignStyle: "Japandi",
            score: 82,
            relevance: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProjectEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProjectEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> ProjectEntry {
        let defaults = UserDefaults(suiteName: "group.com.lumaspace.app")
        let name  = defaults?.string(forKey: "widget_project_name")  ?? "Your Space"
        let rooms = defaults?.integer(forKey: "widget_room_count")   ?? 0
        let style = defaults?.string(forKey: "widget_last_style")
        let score = defaults?.integer(forKey: "widget_room_score")   ?? 0

        return ProjectEntry(
            date: .now,
            projectName: name,
            roomCount: rooms,
            lastDesignStyle: style,
            score: score > 0 ? score : nil,
            relevance: TimelineEntryRelevance(score: 0.8)
        )
    }
}

// MARK: - Small Widget View

struct LumaWidgetSmallView: View {
    let entry: ProjectEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.102, green: 0.478, blue: 0.431),
                            Color(red: 0.059, green: 0.353, blue: 0.318)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text(entry.projectName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let score = entry.score {
                    Text("Score: \(score)/100")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium Widget View

struct LumaWidgetMediumView: View {
    let entry: ProjectEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.102, green: 0.478, blue: 0.431),
                            Color(red: 0.059, green: 0.353, blue: 0.318)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("LumaSpace", systemImage: "house.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(entry.projectName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("\(entry.roomCount) room\(entry.roomCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))

                    if let style = entry.lastDesignStyle {
                        Text("Style: \(style)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let score = entry.score {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("score")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(width: 64, height: 64)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Widget Entry View (picks layout by family)

struct LumaWidgetEntryView: View {
    let entry: ProjectEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            LumaWidgetMediumView(entry: entry)
        default:
            LumaWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct LumaSpaceWidget: Widget {
    let kind = "LumaSpaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LumaProjectProvider()) { entry in
            Link(destination: URL(string: "lumaspace://project/latest")!) {
                LumaWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(red: 0.102, green: 0.478, blue: 0.431)
                    }
            }
        }
        .configurationDisplayName("LumaSpace")
        .description("Your latest interior design project at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct LumaSpaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        LumaSpaceWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    LumaSpaceWidget()
} timeline: {
    ProjectEntry(
        date: .now,
        projectName: "Living Room Refresh",
        roomCount: 2,
        lastDesignStyle: "Japandi",
        score: 82,
        relevance: nil
    )
}
