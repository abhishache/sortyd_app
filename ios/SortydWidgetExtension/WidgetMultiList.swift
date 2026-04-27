import SwiftUI
import WidgetKit

struct MultiListWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family

    private var listsToShow: [WidgetData.MultiListEntry] {
        guard let lists = data.allLists, !lists.isEmpty else { return [] }
        // For Medium widget, we show up to 4 lists in a row as per the user's image.
        return Array(lists.prefix(4))
    }

    var body: some View {
        ZStack {
            WTheme.bg0.ignoresSafeArea()
            
            if listsToShow.isEmpty {
                Text(String(localized: "No lists found"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WTheme.text2)
            } else {
                HStack(spacing: 6) {
                    ForEach(listsToShow) { entry in
                        Link(destination: URL(string: "sortyd://list/\(entry.id.uuidString)")!) {
                            VStack(spacing: 8) {
                                donutGauge(entry: entry)
                                
                                VStack(spacing: 1) {
                                    Text(entry.name.removingLeadingEmojis())
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(WTheme.text0)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(minHeight: 24, alignment: .top)
                                    
                                    Text("\(Int(entry.completionFraction * 100))%")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundColor(WTheme.statusColor(fraction: entry.completionFraction))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    private func donutGauge(entry: WidgetData.MultiListEntry) -> some View {
        ZStack {
            let segments = 24
            let gap: Double = 0.025
            let filledSegments = Int(Double(segments) * entry.completionFraction)
            let size: CGFloat = 50

            ForEach(0..<segments, id: \.self) { i in
                let start = Double(i) / Double(segments)
                let end = start + (1.0 / Double(segments)) - gap

                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        i < filledSegments
                            ? WTheme.arcGradient
                            : AngularGradient(colors: [WTheme.bg3.opacity(0.35)], center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)

            // Glow on filled arc
            if entry.completionFraction > 0 {
                Circle()
                    .trim(from: 0, to: max(0, entry.completionFraction - gap))
                    .stroke(WTheme.primary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 5)
                    .frame(width: size, height: size)
            }

            Text(entry.emoji)
                .font(.system(size: 21))

            // Grade on top-left
            VStack {
                HStack {
                    Text(entry.grade)
                        .font(.system(size: 7.5, weight: .black, design: .rounded))
                        .foregroundColor(gradeColor(entry.grade))
                        .padding(2.5)
                        .background(
                            Circle()
                                .fill(WTheme.bg1)
                                .shadow(color: .black.opacity(0.2), radius: 2)
                        )
                        .offset(x: -size/5, y: -size/5)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: size, height: size)
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        if grade.contains("A") { return WTheme.primary }
        if grade.contains("B") { return WTheme.secondary }
        if grade.contains("C") { return Color(widgetHex: "#FFB74D") }
        return Color(widgetHex: "#FF7043")
    }
}

struct SortydMultiListWidget: Widget {
    let kind = "SortydMultiListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            MultiListWidgetView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(for: .widget) { WTheme.bg0 }
        }
        .configurationDisplayName("List Summary")
        .description("Quick glance at completion across multiple lists.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
