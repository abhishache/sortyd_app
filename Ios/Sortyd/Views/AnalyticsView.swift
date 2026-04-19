//// MARK: - AnalyticsView.swift
//import SwiftUI
//
//struct AnalyticsView: View {
//    @EnvironmentObject var vm: AppViewModel
//    @EnvironmentObject var themeManager: ThemeManager
//    @State private var period: Period = .month
//    @State private var showListPicker = false
//    @State private var heroAppeared = false
//
//    enum Period: String, CaseIterable {
//        case week  = "7D"
//        case month = "30D"
//        case all   = "ALL"
//    }
//
//    private var snaps: [DailySnapshot] {
//        let cal = Calendar.current
//        let today = cal.startOfDay(for: Date())
//        let all = vm.snapshotsForActiveList()
//        var lookup: [Date: DailySnapshot] = [:]
//        for s in all { lookup[cal.startOfDay(for: s.date)] = s }
//        switch period {
//        case .week:  return filledDays(count: 7,  endingOn: today, lookup: lookup)
//        case .month: return filledDays(count: 30, endingOn: today, lookup: lookup)
//        case .all:
//            guard let earliest = all.first.map({ cal.startOfDay(for: $0.date) }) else {
//                return filledDays(count: 1, endingOn: today, lookup: lookup)
//            }
//            let days = cal.dateComponents([.day], from: earliest, to: today).day! + 1
//            return filledDays(count: max(days, 1), endingOn: today, lookup: lookup)
//        }
//    }
//
//    private func filledDays(count: Int, endingOn today: Date, lookup: [Date: DailySnapshot]) -> [DailySnapshot] {
//        let cal = Calendar.current
//        let listID = vm.activeList?.id ?? UUID()
//        return (0..<count).map { offset in
//            let date = cal.date(byAdding: .day, value: -(count - 1 - offset), to: today)!
//            return lookup[date] ?? DailySnapshot(
//                id: UUID(), date: date, listID: listID,
//                completionFraction: 0, completedTaskIDs: []
//            )
//        }
//    }
//
//    private var avg: Int {
//        guard !snaps.isEmpty else { return 0 }
//        return Int((snaps.map(\.completionFraction).reduce(0,+) / Double(snaps.count) * 100).rounded())
//    }
//
//    private var grade: String {
//        switch avg {
//        case 90...100: return "A"
//        case 80..<90:  return "A-"
//        case 75..<80:  return "B+"
//        case 70..<75:  return "B"
//        case 65..<70:  return "B-"
//        case 60..<65:  return "C+"
//        case 50..<60:  return "C"
//        default:       return "D"
//        }
//    }
//
//    private var gradeSubtitle: String {
//        switch avg {
//        case 90...100: return "Exceptional"
//        case 80..<90:  return "Great work"
//        case 75..<80:  return "Almost there"
//        case 70..<75:  return "On track"
//        case 60..<70:  return "Room to grow"
//        case 50..<60:  return "Keep pushing"
//        default:       return "Just starting"
//        }
//    }
//
//    private var gradeAccentColor: Color {
//        switch avg {
//        case 80...100: return Theme.accent
//        case 60..<80:  return Theme.warning
//        default:       return Theme.coral
//        }
//    }
//
//    private var vsLastPeriod: Int? {
//        let all = vm.snapshotsForActiveList()
//        let n = snaps.count
//        guard n > 0 else { return nil }
//        let prevSnaps = Array(all.dropLast(n).suffix(n))
//        guard !prevSnaps.isEmpty else { return nil }
//        let prevAvg = prevSnaps.map(\.completionFraction).reduce(0,+) / Double(prevSnaps.count) * 100
//        return Int((Double(avg) - prevAvg).rounded())
//    }
//
//    private var bestDay: String {
//        guard !snaps.isEmpty else { return "—" }
//        let cal = Calendar.current
//        var dayTotals = [Int: (Double, Int)]()
//        for s in snaps {
//            let wd = cal.component(.weekday, from: s.date)
//            let e = dayTotals[wd] ?? (0, 0)
//            dayTotals[wd] = (e.0 + s.completionFraction, e.1 + 1)
//        }
//        let avgs = dayTotals.mapValues { $0.0 / Double($0.1) }
//        guard let best = avgs.max(by: { $0.value < $1.value }) else { return "—" }
//        return weekdayName(best.key)
//    }
//
//    private var weakestDay: String {
//        guard !snaps.isEmpty else { return "—" }
//        let cal = Calendar.current
//        var dayTotals = [Int: (Double, Int)]()
//        for s in snaps {
//            let wd = cal.component(.weekday, from: s.date)
//            let e = dayTotals[wd] ?? (0, 0)
//            dayTotals[wd] = (e.0 + s.completionFraction, e.1 + 1)
//        }
//        let avgs = dayTotals.mapValues { $0.0 / Double($0.1) }
//        guard let worst = avgs.min(by: { $0.value < $1.value }) else { return "—" }
//        return weekdayName(worst.key)
//    }
//
//    private var bestStreakForPeriod: Int {
//        var best = 0, current = 0
//        for snap in snaps {
//            if snap.completionFraction >= 0.8 { current += 1; best = max(best, current) }
//            else { current = 0 }
//        }
//        return best
//    }
//
//    private func weekdayName(_ weekday: Int) -> String {
//        ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][max(0, min(weekday - 1, 6))]
//    }
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                Theme.bg0.ignoresSafeArea()
//                ScrollView(showsIndicators: false) {
//                    VStack(spacing: 0) {
//                        headerRow
//                            .padding(.horizontal, Theme.s16)
//                            .padding(.top, 12)
//                            .padding(.bottom, 14)
//
//                        heroBlock
//                            .padding(.horizontal, Theme.s16)
//                            .padding(.bottom, 10)
//
//                        insightRibbon
//                            .padding(.horizontal, Theme.s16)
//                            .padding(.bottom, 10)
//
//                        trendChartCard
//                            .padding(.horizontal, Theme.s16)
//                            .padding(.bottom, 10)
//
//                        barsCard
//                            .padding(.horizontal, Theme.s16)
//                            .padding(.bottom, 10)
//
//                        weakAreasCard
//                            .padding(.horizontal, Theme.s16)
//
//                        Spacer(minLength: 80)
//                    }
//                }
//            }
//            .navigationBarHidden(true)
//        }
//        .onAppear {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
//                    heroAppeared = true
//                }
//            }
//        }
//    }
//
//    // MARK: - Header
//    // Order: title | spacer | period selector (compact, fixed) | list picker (broader)
//
//    private var headerRow: some View {
//        HStack(alignment: .center, spacing: 8) {
//            VStack(alignment: .leading, spacing: 1) {
//                Text("ANALYTICS")
//                    .font(.system(size: 9, weight: .bold))
//                    .kerning(2.5)
//                    .foregroundColor(Theme.text2)
//                Text("Report")
//                    .font(.system(size: 26, weight: .black))
//                    .foregroundColor(Theme.text0)
//            }
//
//            Spacer()
//
//            periodSelector
//            listPickerButton
//        }
//    }
//
//    // MARK: - Hero
//
//    private var heroBlock: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
//                .fill(Theme.bg1)
//                .overlay(
//                    RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
//                        .strokeBorder(Theme.borderAccent, lineWidth: 0.75)
//                )
//
//            RadialGradient(
//                colors: [gradeAccentColor.opacity(0.10), Color.clear],
//                center: .topLeading,
//                startRadius: 0,
//                endRadius: 220
//            )
//            .clipShape(RoundedRectangle(cornerRadius: Theme.r24, style: .continuous))
//
//            HStack(alignment: .center, spacing: 0) {
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(grade)
//                        .font(.system(size: 72, weight: .black, design: .rounded))
//                        .foregroundStyle(
//                            LinearGradient(
//                                colors: [gradeAccentColor, gradeAccentColor.opacity(0.65)],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                        )
//                        .scaleEffect(heroAppeared ? 1 : 0.6, anchor: .leading)
//                        .opacity(heroAppeared ? 1 : 0)
//                        .lineLimit(1)
//                        .minimumScaleFactor(0.5)
//                    Text(gradeSubtitle)
//                        .font(.system(size: 10, weight: .semibold))
//                        .foregroundColor(gradeAccentColor.opacity(0.60))
//                }
//                .padding(.leading, Theme.s16)
//                .padding(.vertical, Theme.s16)
//
//                Spacer()
//
//                Rectangle()
//                    .fill(Theme.border)
//                    .frame(width: 0.5, height: 56)
//
//                HStack(spacing: 20) {
//                    heroStat(label: "AVG", value: "\(avg)", unit: "%", color: Theme.text0)
//                    heroStat(label: "STREAK", value: "\(bestStreakForPeriod)", unit: "d", color: Theme.coral)
//                }
//                .padding(.trailing, Theme.s16)
//                .padding(.vertical, Theme.s16)
//            }
//        }
//        .dualGlow(violetIntensity: 0.14, cyanIntensity: 0.08)
//    }
//
//    private func heroStat(label: String, value: String, unit: String, color: Color) -> some View {
//        VStack(alignment: .trailing, spacing: 1) {
//            Text(label)
//                .font(.system(size: 8, weight: .bold))
//                .kerning(1.8)
//                .foregroundColor(Theme.text2)
//            HStack(alignment: .firstTextBaseline, spacing: 1) {
//                Text(value)
//                    .font(.system(size: 28, weight: .black, design: .rounded))
//                    .foregroundColor(color)
//                Text(unit)
//                    .font(.system(size: 13, weight: .bold, design: .rounded))
//                    .foregroundColor(color.opacity(0.5))
//            }
//        }
//    }
//
//    // MARK: - Period Selector
//    // Compact capsule pill (old style). Fixed size. Spring animation on pill.
//
//    private var periodSelector: some View {
//        HStack(spacing: 0) {
//            ForEach(Period.allCases, id: \.self) { p in
//                Button(action: {
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
//                        period = p
//                    }
//                }) {
//                    Text(p.rawValue)
//                        .font(.system(size: 11, weight: .bold, design: .rounded))
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 7)
//                        .foregroundColor(period == p ? Theme.bg0 : Theme.text2)
//                        .background(
//                            Group {
//                                if period == p {
//                                    Capsule(style: .continuous)
//                                        .fill(Theme.accent)
//                                        .amberGlow(intensity: 0.2)
//                                } else {
//                                    Capsule(style: .continuous).fill(Color.clear)
//                                }
//                            }
//                        )
//                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: period)
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .padding(3)
//        .background(
//            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                .fill(Theme.bg1)
//                .overlay(
//                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                        .strokeBorder(Theme.border, lineWidth: 0.5)
//                )
//        )
//        .cardShadow()
//        .fixedSize()
//    }
//
//    // MARK: - List Picker
//    // Broader, flexible. Sits right of period selector.
//
//    private var listPickerButton: some View {
//        Button(action: { showListPicker = true }) {
//            HStack(spacing: 6) {
//                Text(vm.activeList?.emoji ?? "📋")
//                    .font(.system(size: 13))
//                Text(vm.activeList?.name ?? "No list")
//                    .font(.system(size: 12, weight: .semibold))
//                    .foregroundColor(Theme.text0)
//                    .lineLimit(1)
//                    .truncationMode(.tail)
//                Spacer(minLength: 2)
//                Image(systemName: "chevron.down")
//                    .font(.system(size: 9, weight: .bold))
//                    .foregroundColor(Theme.text2)
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//            .frame(minWidth: 110, maxWidth: 150)
//            .background(
//                Capsule(style: .continuous)
//                    .fill(Theme.bg2)
//                    .overlay(
//                        Capsule(style: .continuous)
//                            .strokeBorder(Theme.border, lineWidth: 0.5)
//                    )
//            )
//            .cardShadow()
//        }
//        .buttonStyle(.plain)
//        .sheet(isPresented: $showListPicker) {
//            ListSwitcherSheet().environmentObject(vm)
//        }
//    }
//
//    // MARK: - Insight ribbon
//
//    private var insightRibbon: some View {
//        HStack(spacing: 8) {
//            if let vs = vsLastPeriod {
//                ribbonChip(
//                    icon: vs >= 0 ? "arrow.up.right" : "arrow.down.right",
//                    value: vs >= 0 ? "+\(vs)%" : "\(vs)%",
//                    label: "VS LAST",
//                    valueColor: vs >= 0 ? Theme.accent : Theme.danger,
//                    iconColor:  vs >= 0 ? Theme.accent : Theme.danger
//                )
//            } else {
//                ribbonChip(icon: "minus", value: "N/A", label: "VS LAST",
//                           valueColor: Theme.text2, iconColor: Theme.text2)
//            }
//            ribbonChip(icon: "star.fill",  value: bestDay,    label: "BEST DAY",
//                       valueColor: Theme.text0, iconColor: Theme.accent)
//            ribbonChip(icon: "moon.fill",  value: weakestDay, label: "WEAKEST",
//                       valueColor: Theme.text0, iconColor: Theme.coral)
//        }
//    }
//
//    private func ribbonChip(icon: String, value: String, label: String,
//                             valueColor: Color, iconColor: Color) -> some View {
//        VStack(spacing: 5) {
//            Image(systemName: icon)
//                .font(.system(size: 10, weight: .semibold))
//                .foregroundColor(iconColor)
//            Text(value)
//                .font(.system(size: 15, weight: .black, design: .rounded))
//                .foregroundColor(valueColor)
//                .minimumScaleFactor(0.7)
//                .lineLimit(1)
//            Text(label)
//                .font(.system(size: 7.5, weight: .bold))
//                .kerning(0.6)
//                .foregroundColor(Theme.text2)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 11)
//        .background(
//            RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
//                .fill(Theme.bg1)
//                .overlay(
//                    RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
//                        .strokeBorder(Theme.border, lineWidth: 0.5)
//                )
//        )
//        .cardShadow()
//    }
//
//    // MARK: - Trend chart card
//
//    private var trendChartTitle: String {
//        switch period {
//        case .week:  return "7-DAY TREND"
//        case .month: return "30-DAY TREND"
//        case .all:   return "ALL-TIME TREND"
//        }
//    }
//
//    private var trendChartCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text(trendChartTitle)
//                    .font(.system(size: 9, weight: .bold))
//                    .kerning(1.8)
//                    .foregroundColor(Theme.text2)
//                    .id(trendChartTitle)
//                    .transition(.opacity)
//                Spacer()
//                HStack(spacing: 4) {
//                    Circle().fill(Theme.accent).frame(width: 4, height: 4)
//                    Text("completion")
//                        .font(.system(size: 9, weight: .medium))
//                        .foregroundColor(Theme.text2)
//                }
//            }
//            .animation(.easeInOut(duration: 0.2), value: trendChartTitle)
//
//            Group {
//                if snaps.count >= 2 {
//                    SmoothLineChart(snapshots: snaps)
//                        .frame(height: 140)
//                        .transition(.asymmetric(
//                            insertion: .opacity.combined(with: .move(edge: .trailing)),
//                            removal:   .opacity.combined(with: .move(edge: .leading))
//                        ))
//                        .id(period)
//                } else {
//                    VStack(spacing: 6) {
//                        Image(systemName: "chart.line.uptrend.xyaxis")
//                            .font(.system(size: 20))
//                            .foregroundColor(Theme.text2)
//                        Text("Not enough data yet")
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(Theme.text2)
//                    }
//                    .frame(maxWidth: .infinity).frame(height: 70)
//                }
//            }
//            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: period)
//        }
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                .fill(Theme.bg1)
//                .overlay(
//                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                        .strokeBorder(Theme.border, lineWidth: 0.5)
//                )
//        )
//        .cardShadow()
//    }
//
//    // MARK: - Bars card
//
//    private var barsCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("LAST 14 DAYS")
//                    .font(.system(size: 9, weight: .bold))
//                    .kerning(1.8)
//                    .foregroundColor(Theme.text2)
//                Spacer()
//                HStack(spacing: 10) {
//                    legendPill(color: Theme.accent, label: "80%+")
//                    legendPill(color: Theme.coral,  label: "40%+")
//                }
//            }
//            GradientBarChart(snapshots: Array(snaps.suffix(14))).frame(height: 90)
//        }
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                .fill(Theme.bg1)
//                .overlay(
//                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                        .strokeBorder(Theme.border, lineWidth: 0.5)
//                )
//        )
//        .cardShadow()
//    }
//
//    private func legendPill(color: Color, label: String) -> some View {
//        HStack(spacing: 4) {
//            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 3)
//            Text(label).font(.system(size: 8.5, weight: .medium)).foregroundColor(Theme.text2)
//        }
//    }
//
//    // MARK: - Weak areas card
//    // Uniform 3-col compact grid. All tiles same size. Dense, scannable.
//
//    @ViewBuilder
//    private var weakAreasCard: some View {
//        let weak = computeWeakTasks()
//        if !weak.isEmpty {
//            VStack(alignment: .leading, spacing: 10) {
//                HStack(alignment: .center) {
//                    HStack(spacing: 5) {
//                        Image(systemName: "exclamationmark.triangle.fill")
//                            .font(.system(size: 9))
//                            .foregroundColor(Theme.coral)
//                        Text("NEEDS WORK")
//                            .font(.system(size: 9, weight: .bold))
//                            .kerning(1.6)
//                            .foregroundColor(Theme.text2)
//                    }
//                    Spacer()
//                    Text("\(weak.count) tasks")
//                        .font(.system(size: 10, weight: .semibold, design: .rounded))
//                        .foregroundColor(Theme.accent)
//                }
//
//                LazyVGrid(
//                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
//                    spacing: 8
//                ) {
//                    ForEach(weak) { item in
//                        WeakCompactTile(item: item)
//                    }
//                }
//            }
//            .padding(14)
//            .background(
//                RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                    .fill(Theme.bg1)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
//                            .strokeBorder(Theme.border, lineWidth: 0.5)
//                    )
//            )
//            .cardShadow()
//        }
//    }
//
//    struct WeakItem: Identifiable {
//        var id = UUID()
//        var title: String
//        var missRate: Double
//    }
//
//    private func computeWeakTasks() -> [WeakItem] {
//        guard let list = vm.activeList, !snaps.isEmpty else { return [] }
//        return list.tasks.compactMap { task in
//            let hits = snaps.filter { $0.completedTaskIDs.contains(task.id) }.count
//            let miss = 1.0 - Double(hits) / Double(snaps.count)
//            return miss > 0.3 ? WeakItem(title: task.title, missRate: miss) : nil
//        }
//        .sorted { $0.missRate > $1.missRate }
//        .prefix(6).map { $0 }
//    }
//}
//
//// MARK: - WeakCompactTile
//// Tight 3-col tile. Severity dot + truncated title. Large miss% dominates.
//// Flush 3pt bar at bottom as visual progress indicator.
//
//struct WeakCompactTile: View {
//    let item: AnalyticsView.WeakItem
//
//    private var color: Color {
//        item.missRate > 0.75 ? Theme.danger
//            : item.missRate > 0.5 ? Theme.coral
//            : Theme.accent
//    }
//    private var fillOpacity: Double   { item.missRate > 0.75 ? 0.13 : item.missRate > 0.5 ? 0.09 : 0.06 }
//    private var borderOpacity: Double { item.missRate > 0.75 ? 0.28 : item.missRate > 0.5 ? 0.20 : 0.13 }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//
//            // Severity dot + title
//            HStack(alignment: .top, spacing: 5) {
//                Circle()
//                    .fill(color)
//                    .frame(width: 5, height: 5)
//                    .padding(.top, 3)
//                Text(item.title)
//                    .font(.system(size: 10, weight: .semibold))
//                    .foregroundColor(Theme.text0)
//                    .lineLimit(2)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//            .padding(.horizontal, 8)
//            .padding(.top, 9)
//
//            Spacer(minLength: 4)
//
//            // Miss % number
//            HStack(alignment: .lastTextBaseline, spacing: 1) {
//                Text("\(Int(item.missRate * 100))")
//                    .font(.system(size: 24, weight: .black, design: .rounded))
//                    .foregroundColor(color)
//                    .monospacedDigit()
//                    .minimumScaleFactor(0.75)
//                    .lineLimit(1)
//                Text("%")
//                    .font(.system(size: 10, weight: .bold, design: .rounded))
//                    .foregroundColor(color.opacity(0.45))
//            }
//            .padding(.horizontal, 8)
//            .padding(.bottom, 7)
//
//            // Flush bottom progress bar
//            GeometryReader { geo in
//                ZStack(alignment: .leading) {
//                    Rectangle()
//                        .fill(color.opacity(0.10))
//                        .frame(height: 3)
//                    Rectangle()
//                        .fill(LinearGradient(
//                            colors: [color, color.opacity(0.20)],
//                            startPoint: .leading, endPoint: .trailing
//                        ))
//                        .frame(width: geo.size.width * item.missRate, height: 3)
//                }
//            }
//            .frame(height: 3)
//        }
//        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
//        .background(
//            RoundedRectangle(cornerRadius: 11, style: .continuous)
//                .fill(color.opacity(fillOpacity))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 11, style: .continuous)
//                        .strokeBorder(color.opacity(borderOpacity), lineWidth: 0.75)
//                )
//        )
//        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
//    }
//}
//
//// MARK: - SmoothLineChart
//
//struct SmoothLineChart: View {
//    let snapshots: [DailySnapshot]
//    @State private var appear = false
//
//    private var values: [Double] { snapshots.map(\.completionFraction) }
//
//    private static let axisFormatter: DateFormatter = {
//        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
//    }()
//
//    private func axisLabel(for date: Date) -> String {
//        Calendar.current.isDateInToday(date) ? "Today" : Self.axisFormatter.string(from: date)
//    }
//
//    var body: some View {
//        VStack(spacing: 5) {
//            GeometryReader { geo in
//                let w = geo.size.width
//                let h = geo.size.height
//                let pts = points(w: w, h: h)
//
//                ZStack(alignment: .bottomLeading) {
//                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
//                        let y = h - CGFloat(level) * h * 0.88
//                        Path { p in
//                            p.move(to: CGPoint(x: 0, y: y))
//                            p.addLine(to: CGPoint(x: w, y: y))
//                        }
//                        .stroke(Theme.border, style: StrokeStyle(lineWidth: 0.5, dash: [3, 5]))
//                    }
//
//                    ForEach([25, 50, 75, 100], id: \.self) { pct in
//                        let y = h - CGFloat(Double(pct)/100) * h * 0.88
//                        Text("\(pct)%")
//                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
//                            .foregroundColor(Theme.text2)
//                            .position(x: 14, y: y)
//                    }
//
//                    if pts.count >= 2 {
//                        Path { p in
//                            p.move(to: CGPoint(x: pts[0].x, y: h))
//                            smoothPath(points: pts, path: &p)
//                            p.addLine(to: CGPoint(x: pts.last!.x, y: h))
//                            p.closeSubpath()
//                        }
//                        .fill(
//                            LinearGradient(
//                                colors: [Theme.accent.opacity(appear ? 0.18 : 0), Theme.accent.opacity(0)],
//                                startPoint: .top, endPoint: .bottom
//                            )
//                        )
//                        .animation(.easeOut(duration: 0.8), value: appear)
//
//                        Path { p in
//                            p.move(to: pts[0])
//                            smoothPath(points: pts, path: &p)
//                        }
//                        .trim(from: 0, to: appear ? 1 : 0)
//                        .stroke(
//                            LinearGradient(
//                                colors: [Theme.coral, Theme.accent],
//                                startPoint: .leading, endPoint: .trailing
//                            ),
//                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
//                        )
//                        .animation(.easeOut(duration: 1.0), value: appear)
//
//                        if let last = pts.last {
//                            ZStack {
//                                Circle().fill(Theme.accent.opacity(0.22)).frame(width: 12, height: 12)
//                                Circle().fill(Theme.accent).frame(width: 5, height: 5)
//                            }
//                            .shadow(color: Theme.accent.opacity(0.6), radius: 5)
//                            .position(last)
//                            .opacity(appear ? 1 : 0)
//                            .animation(.easeOut(duration: 0.4).delay(0.9), value: appear)
//                        }
//                    }
//                }
//            }
//
//            if snapshots.count >= 2 {
//                HStack {
//                    Text(axisLabel(for: snapshots.first!.date))
//                        .font(.system(size: 7.5, weight: .medium))
//                        .foregroundColor(Theme.text2)
//                    Spacer()
//                    if snapshots.count >= 7, let midSnap = snapshots[safe: snapshots.count / 2] {
//                        Text(axisLabel(for: midSnap.date))
//                            .font(.system(size: 7.5, weight: .medium))
//                            .foregroundColor(Theme.text2)
//                    }
//                    Spacer()
//                    Text(axisLabel(for: snapshots.last!.date))
//                        .font(.system(size: 7.5, weight: .semibold))
//                        .foregroundColor(Theme.accent)
//                }
//                .padding(.horizontal, 3)
//            }
//        }
//        .onAppear {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appear = true }
//        }
//    }
//
//    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
//        guard values.count >= 2 else { return [] }
//        let step = w / CGFloat(values.count - 1)
//        return values.enumerated().map { i, v in
//            CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) * h * 0.88)
//        }
//    }
//
//    private func smoothPath(points pts: [CGPoint], path: inout Path) {
//        guard pts.count >= 2 else { return }
//        for i in 1..<pts.count {
//            let prev = pts[i - 1], curr = pts[i]
//            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) / 3, y: prev.y)
//            let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) / 3, y: curr.y)
//            path.addCurve(to: curr, control1: cp1, control2: cp2)
//        }
//    }
//}
//
//// MARK: - GradientBarChart
//
//struct GradientBarChart: View {
//    let snapshots: [DailySnapshot]
//
//    private static let monthDayFormatter: DateFormatter = {
//        let f = DateFormatter(); f.dateFormat = "M/d"; return f
//    }()
//
//    private func barLabel(for date: Date) -> String {
//        Calendar.current.isDateInToday(date) ? "Today" : Self.monthDayFormatter.string(from: date)
//    }
//
//    var body: some View {
//        GeometryReader { geo in
//            let n = snapshots.count
//            let barW = n > 0 ? (geo.size.width - CGFloat(n - 1) * 3) / CGFloat(n) : 0
//            let maxH = geo.size.height - 16
//
//            if n > 0 {
//                HStack(alignment: .bottom, spacing: 3) {
//                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, snap in
//                        let isToday   = Calendar.current.isDateInToday(snap.date)
//                        let isFirst   = idx == 0
//                        let isLast    = idx == snapshots.count - 1
//                        let showLabel = isFirst || isLast || idx == snapshots.count / 2
//
//                        VStack(spacing: 3) {
//                            Spacer(minLength: 0)
//                            RoundedRectangle(cornerRadius: 3, style: .continuous)
//                                .fill(
//                                    isToday || snap.completionFraction >= 0.8
//                                        ? Theme.amberGlow
//                                        : snap.completionFraction >= 0.4
//                                            ? Theme.mintGlow
//                                            : LinearGradient(
//                                                colors: [Theme.text2.opacity(0.35), Theme.text2.opacity(0.12)],
//                                                startPoint: .top, endPoint: .bottom)
//                                )
//                                .frame(width: barW, height: max(CGFloat(snap.completionFraction) * maxH, 2))
//                                .shadow(
//                                    color: (isToday || snap.completionFraction >= 0.8)
//                                        ? Theme.accent.opacity(0.22)
//                                        : snap.completionFraction >= 0.4
//                                            ? Theme.coral.opacity(0.18)
//                                            : .clear,
//                                    radius: 3
//                                )
//
//                            Text(isLast ? "Today" : (showLabel ? barLabel(for: snap.date) : ""))
//                                .font(.system(size: 6.5, weight: isLast ? .bold : .regular))
//                                .foregroundColor(isLast ? Theme.accent : Theme.text2)
//                                .frame(width: barW)
//                                .lineLimit(1)
//                                .minimumScaleFactor(0.5)
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Array safe subscript
//
//private extension Array {
//    subscript(safe index: Int) -> Element? {
//        indices.contains(index) ? self[index] : nil
//    }
//}
//
//#Preview {
//    AnalyticsView()
//        .environmentObject(AppViewModel())
//        .environmentObject(ThemeManager.shared)
//}



// MARK: - AnalyticsView.swift
import SwiftUI
import FirebaseAnalytics

struct AnalyticsView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var period: Period = .month
    @State private var showListPicker = false
    @State private var heroAppeared = false
    @State private var selectedListID: UUID? = nil

    private var resolvedListID: UUID { selectedListID ?? vm.activeListID ?? UUID() }

    enum Period: String, CaseIterable {
        case week  = "7D"
        case month = "30D"
        case all   = "ALL"
    }

    private var snaps: [DailySnapshot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let all = vm.snapshotsForList(id: resolvedListID)
        var lookup: [Date: DailySnapshot] = [:]
        for s in all { lookup[cal.startOfDay(for: s.date)] = s }
        switch period {
        case .week:  return filledDays(count: 7,  endingOn: today, lookup: lookup)
        case .month: return filledDays(count: 30, endingOn: today, lookup: lookup)
        case .all:
            let installDateAll: Date = {
                let key = "sortyd_install_date"
                if let d = UserDefaults.standard.object(forKey: key) as? Date { return cal.startOfDay(for: d) }
                let now = cal.startOfDay(for: Date())
                UserDefaults.standard.set(Date(), forKey: key)
                return now
            }()
            let earliestSnap = all.first.map { cal.startOfDay(for: $0.date) }
            let earliest = earliestSnap.map { min($0, installDateAll) } ?? installDateAll
            let days = (cal.dateComponents([.day], from: earliest, to: today).day ?? 0) + 1
            return filledDays(count: max(days, 1), endingOn: today, lookup: lookup)
        }
    }

    private func filledDays(count: Int, endingOn today: Date, lookup: [Date: DailySnapshot]) -> [DailySnapshot] {
        let cal = Calendar.current
        let listID = resolvedListID
        // compactMap + guard: cal.date(byAdding:) is nil only in extraordinary edge cases,
        // but force-unwrapping it would crash those users. Silently skip any failed dates.
        return (0..<count).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -(count - 1 - offset), to: today) else { return nil }
            return lookup[date] ?? DailySnapshot(
                id: UUID(), date: date, listID: listID,
                completionFraction: 0, completedTaskIDs: []
            )
        }
    }

    private var avg: Int {
        guard !snaps.isEmpty else { return 0 }
        return Int((snaps.map(\.completionFraction).reduce(0,+) / Double(snaps.count) * 100).rounded())
    }

    private var grade: String {
        switch avg {
        case 90...100: return "A"
        case 80..<90:  return "A-"
        case 75..<80:  return "B+"
        case 70..<75:  return "B"
        case 65..<70:  return "B-"
        case 60..<65:  return "C+"
        case 50..<60:  return "C"
        default:       return "D"
        }
    }

    private var gradeSubtitle: String {
        switch avg {
        case 90...100: return "Exceptional"
        case 80..<90:  return "Great work"
        case 75..<80:  return "Almost there"
        case 70..<75:  return "On track"
        case 60..<70:  return "Room to grow"
        case 50..<60:  return "Keep pushing"
        default:       return "Just starting"
        }
    }

    private var gradeAccentColor: Color {
        switch avg {
        case 80...100: return Theme.accent
        case 60..<80:  return Theme.warning
        default:       return Theme.coral
        }
    }

    private var vsLastPeriod: Int? {
        let all = vm.snapshotsForList(id: resolvedListID)
        let n = snaps.count
        guard n > 0 else { return nil }
        let prevSnaps = Array(all.dropLast(n).suffix(n))
        guard !prevSnaps.isEmpty else { return nil }
        let prevAvg = prevSnaps.map(\.completionFraction).reduce(0,+) / Double(prevSnaps.count) * 100
        return Int((Double(avg) - prevAvg).rounded())
    }

    private var bestDay: String {
        guard !snaps.isEmpty else { return "—" }
        let cal = Calendar.current
        var dayTotals = [Int: (Double, Int)]()
        for s in snaps {
            let wd = cal.component(.weekday, from: s.date)
            let e = dayTotals[wd] ?? (0, 0)
            dayTotals[wd] = (e.0 + s.completionFraction, e.1 + 1)
        }
        let avgs = dayTotals.mapValues { $0.0 / Double($0.1) }
        guard let best = avgs.max(by: { $0.value < $1.value }) else { return "—" }
        return weekdayName(best.key)
    }

    private var weakestDay: String {
        guard !snaps.isEmpty else { return "—" }
        let cal = Calendar.current
        var dayTotals = [Int: (Double, Int)]()
        for s in snaps {
            let wd = cal.component(.weekday, from: s.date)
            let e = dayTotals[wd] ?? (0, 0)
            dayTotals[wd] = (e.0 + s.completionFraction, e.1 + 1)
        }
        let avgs = dayTotals.mapValues { $0.0 / Double($0.1) }
        guard let worst = avgs.min(by: { $0.value < $1.value }) else { return "—" }
        return weekdayName(worst.key)
    }

    private var bestStreakForPeriod: Int {
        var best = 0, current = 0
        for snap in snaps {
            if snap.completionFraction >= 0.8 { current += 1; best = max(best, current) }
            else { current = 0 }
        }
        return best
    }

    private func weekdayName(_ weekday: Int) -> String {
        ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][max(0, min(weekday - 1, 6))]
    }

    // MARK: - Task DNA helpers

    struct TaskDNAItem: Identifiable {
        var id: UUID
        var title: String
        var rate: Double   // 0–1 completion rate
        var streak: Int    // current streak days
    }

    private var taskDNAItems: [TaskDNAItem] {
        guard let list = vm.listForID(resolvedListID), !snaps.isEmpty else { return [] }
        return list.tasks.map { task in
            let hits = snaps.filter { $0.completedTaskIDs.contains(task.id) }.count
            let rate = Double(hits) / Double(snaps.count)
            // streak: count consecutive trailing days with completion
            var streak = 0
            for snap in snaps.reversed() {
                if snap.completedTaskIDs.contains(task.id) { streak += 1 } else { break }
            }
            return TaskDNAItem(id: task.id, title: task.title, rate: rate, streak: streak)
        }
        .sorted { $0.rate > $1.rate }
    }

    private var weakTasks: [TaskDNAItem] {
        taskDNAItems.filter { $0.rate < 0.7 }.sorted { $0.rate < $1.rate }.prefix(5).map { $0 }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerRow
                            .padding(.horizontal, Theme.s16)
                            .padding(.top, 12)
                            .padding(.bottom, 14)

                        NewUserBanner()
                            .environmentObject(vm)
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 8)

                        heroBlock
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        // ↓ Insight ribbon height reduced 10% (via internal padding tweak)
                        insightRibbon
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        trendChartCard
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        weekdayHeatmapCard
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        taskDNACard
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        if !weakTasks.isEmpty {
                            weakAreasCompact
                                .padding(.horizontal, Theme.s16)
                                .padding(.bottom, 10)
                        }

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if selectedListID == nil { selectedListID = vm.activeListID }
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "analytics",
                AnalyticsParameterScreenClass: "AnalyticsView"
            ])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    heroAppeared = true
                }
            }
        }
        .onChange(of: selectedListID) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                heroAppeared = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    heroAppeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("ANALYTICS")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(2.5)
                    .foregroundColor(Theme.text2)
                Text("Report")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(Theme.text0)
            }
            Spacer()
            periodSelector
            listPickerButton
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
                        .strokeBorder(Theme.borderAccent, lineWidth: 0.75)
                )

            RadialGradient(
                colors: [gradeAccentColor.opacity(0.10), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.r24, style: .continuous))

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(grade)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [gradeAccentColor, gradeAccentColor.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(heroAppeared ? 1 : 0.6, anchor: .leading)
                        .opacity(heroAppeared ? 1 : 0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(gradeSubtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(gradeAccentColor.opacity(0.60))
                }
                .padding(.leading, Theme.s16)
                .padding(.vertical, Theme.s16)

                Spacer()

                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 0.5, height: 56)

                HStack(spacing: 20) {
                    heroStat(label: "AVG",    value: "\(avg)",                unit: "%", color: Theme.text0)
                    heroStat(label: "STREAK", value: "\(bestStreakForPeriod)", unit: "d", color: Theme.coral)
                }
                .padding(.trailing, Theme.s16)
                .padding(.vertical, Theme.s16)
            }
        }
        .dualGlow(violetIntensity: 0.14, cyanIntensity: 0.08)
    }

    private func heroStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .kerning(1.8)
                .foregroundColor(Theme.text2)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(color.opacity(0.5))
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { p in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { period = p }
                }) {
                    Text(p.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundColor(period == p ? Theme.bg0 : Theme.text2)
                        .background(
                            Group {
                                if period == p {
                                    Capsule(style: .continuous)
                                        .fill(Theme.accent)
                                        .amberGlow(intensity: 0.2)
                                } else {
                                    Capsule(style: .continuous).fill(Color.clear)
                                }
                            }
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: period)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
        .fixedSize()
    }

    // MARK: - List Picker (local — does not change home active list)

    private var selectedList: TaskList? { vm.listForID(resolvedListID) }

    private var listPickerButton: some View {
        Button(action: { showListPicker = true }) {
            HStack(spacing: 6) {
                Text(selectedList?.emoji ?? "📋")
                    .font(.system(size: 13))
                Text(selectedList?.name ?? "No list")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text0)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.text2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 110, maxWidth: 150)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.bg2)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 0.5)
                    )
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showListPicker) {
            AnalyticsListPickerSheet(selectedListID: $selectedListID)
                .environmentObject(vm)
        }
    }

    // MARK: - Insight Ribbon (height reduced ~10% via vertical padding)

    private var insightRibbon: some View {
        HStack(spacing: 8) {
            if let vs = vsLastPeriod {
                ribbonChip(
                    icon: vs >= 0 ? "arrow.up.right" : "arrow.down.right",
                    value: vs >= 0 ? "+\(vs)%" : "\(vs)%",
                    label: "VS LAST",
                    valueColor: vs >= 0 ? Theme.accent : Theme.danger,
                    iconColor:  vs >= 0 ? Theme.accent : Theme.danger
                )
            } else {
                ribbonChip(icon: "minus", value: "N/A", label: "VS LAST",
                           valueColor: Theme.text2, iconColor: Theme.text2)
            }
            ribbonChip(icon: "star.fill",  value: bestDay,    label: "BEST DAY",
                       valueColor: Theme.text0, iconColor: Theme.accent)
            ribbonChip(icon: "moon.fill",  value: weakestDay, label: "WEAKEST",
                       valueColor: Theme.text0, iconColor: Theme.coral)
        }
    }

    // Reduced vertical padding by ~10% (from 11 → 10)
    private func ribbonChip(icon: String, value: String, label: String,
                             valueColor: Color, iconColor: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7.5, weight: .bold))
                .kerning(0.6)
                .foregroundColor(Theme.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)   // was 11 → 10 (≈ -9%)
        .background(
            RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    // MARK: - Trend Chart Card (height reduced 10%: 126 → 114)

    private var trendChartTitle: String {
        switch period {
        case .week:  return "7-DAY TREND"
        case .month: return "30-DAY TREND"
        case .all:   return "ALL-TIME TREND"
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trendChartTitle)
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(Theme.text2)
                    .id(trendChartTitle)
                    .transition(.opacity)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Theme.accent).frame(width: 4, height: 4)
                    Text("completion")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: trendChartTitle)

            Group {
                if snaps.count >= 2 {
                    SmoothLineChart(snapshots: snaps)
                        .frame(height: 114)   // was 126 → 114 (-9.5%)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(period)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.text2)
                        Text("Not enough data yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity).frame(height: 58)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: period)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    // MARK: - Weekday Heatmap Card (moved up, after trend chart)

    private var weekdayHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAY-OF-WEEK PATTERN")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.8)
                        .foregroundColor(Theme.text2)
                    Text("When you perform best")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text0.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 5) {
                    Text("LOW")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.text2)
                    HStack(spacing: 2) {
                        ForEach([0.1, 0.35, 0.6, 0.85, 1.0], id: \.self) { intensity in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: intensity))
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text("HIGH")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.text2)
                }
            }

            WeekdayHeatmap(snapshots: snaps)
                .frame(height: 78)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    private func heatmapColor(for intensity: Double) -> Color {
        Theme.heatColor(fraction: intensity)
    }

    // MARK: - Task DNA Card (replaces Momentum card)

    private var taskDNACard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TASK DNA")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.8)
                        .foregroundColor(Theme.text2)
                    Text("Per-task completion breakdown")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text0.opacity(0.40))
                }
                Spacer()
                // Consistency badge: % of tasks above 70% completion
                let items = taskDNAItems
                if !items.isEmpty {
                    let strong = items.filter { $0.rate >= 0.7 }.count
                    let pct = Int(Double(strong) / Double(items.count) * 100)
                    HStack(spacing: 4) {
                        Image(systemName: pct >= 70 ? "checkmark.seal.fill" : pct >= 40 ? "seal.fill" : "xmark.seal.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(pct)% solid")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(pct >= 70 ? Theme.accent : pct >= 40 ? Theme.warning : Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill((pct >= 70 ? Theme.accent : pct >= 40 ? Theme.warning : Theme.danger).opacity(0.12))
                    )
                }
            }

            let items = taskDNAItems
            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "dna")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.text2)
                    Text("No task data yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
                .frame(maxWidth: .infinity).frame(height: 60)
            } else {
                TaskDNAChart(items: items)
                    .frame(height: 160)
                    .id(period)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    ))
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: period)

                // Top performer callout
                if let top = items.first, let bottom = items.last, top.id != bottom.id {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(Theme.accent)
                        Text("\"\(top.title)\" leads at \(Int(top.rate * 100))% · \"\(bottom.title)\" needs the most focus (\(Int(bottom.rate * 100))%)")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                            .lineLimit(2)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    // MARK: - Weak Areas (compact horizontal scroll strip)

    private var weakAreasCompact: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.coral)
                    Text("NEEDS WORK")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.6)
                        .foregroundColor(Theme.text2)
                }
                Spacer()
                Text("\(weakTasks.count) tasks")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weakTasks) { item in
                        weakChip(item)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    private func weakChip(_ item: TaskDNAItem) -> some View {
        let color: Color = item.rate < 0.3 ? Theme.danger : item.rate < 0.5 ? Theme.coral : Theme.warning
        return VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.text0)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(item.rate * 100))")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text("%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.5))
            }

            // Mini progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.12)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [color, color.opacity(0.3)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * item.rate, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color.opacity(0.20), lineWidth: 0.75)
                )
        )
    }
}

// MARK: - TaskDNAChart
// Horizontal bar chart with color-coded completion rates and streak dots

struct TaskDNAChart: View {
    let items: [AnalyticsView.TaskDNAItem]
    @State private var appear = false

    private func barColor(for rate: Double) -> Color {
        rate >= 0.8 ? Theme.accent
            : rate >= 0.6 ? Theme.warning
            : Theme.coral
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let rowH: CGFloat = 20
            let spacing: CGFloat = 7
            let labelW: CGFloat = min(w * 0.30, 90)
            let barZoneW = w - labelW - 36  // 36 reserved for % label + streak dot

            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(items.prefix(6).enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 6) {
                        // Task label
                        Text(item.title)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Theme.text0)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: labelW, alignment: .leading)

                        // Bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Theme.border.opacity(0.5))
                                .frame(height: rowH)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [barColor(for: item.rate), barColor(for: item.rate).opacity(0.55)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: appear ? barZoneW * CGFloat(item.rate) : 0, height: rowH)
                                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(idx) * 0.07), value: appear)
                        }
                        .frame(width: barZoneW, height: rowH)

                        // Percentage
                        Text("\(Int(item.rate * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(barColor(for: item.rate))
                            .frame(width: 26, alignment: .trailing)
                            .monospacedDigit()

                        // Streak fire dot
                        if item.streak >= 3 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                                .foregroundColor(Theme.coral)
                        } else {
                            Spacer().frame(width: 8)
                        }
                    }
                    .frame(height: rowH)
                    .opacity(appear ? 1 : 0)
                    .offset(x: appear ? 0 : -10)
                    .animation(.easeOut(duration: 0.35).delay(Double(idx) * 0.07), value: appear)
                }

                // Legend
                HStack(spacing: 14) {
                    legendItem(color: Theme.accent,  label: "≥ 80%  Strong")
                    legendItem(color: Theme.warning, label: "60–79%  OK")
                    legendItem(color: Theme.coral,   label: "< 60%  Weak")
                    Image(systemName: "flame.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Theme.coral)
                    Text("3d+ streak")
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                    Spacer()
                }
                .padding(.top, 4)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.5), value: appear)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appear = true }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundColor(Theme.text2)
        }
    }
}

// MARK: - WeekdayHeatmap

struct WeekdayHeatmap: View {
    let snapshots: [DailySnapshot]
    @State private var appeared = false

    private let displayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]
    private let dayLabels:    [String] = ["M", "T", "W", "T", "F", "S", "S"]

    private var weekdayAverages: [Int: Double] {
        let cal = Calendar.current
        var totals = [Int: (sum: Double, count: Int)]()
        for snap in snapshots {
            let wd = cal.component(.weekday, from: snap.date)
            let existing = totals[wd] ?? (0, 0)
            totals[wd] = (existing.sum + snap.completionFraction, existing.count + 1)
        }
        return totals.mapValues { $0.sum / Double($0.count) }
    }

    private var bestWeekday: Int? {
        weekdayAverages.max(by: { $0.value < $1.value })?.key
    }

    private var worstWeekday: Int? {
        weekdayAverages.min(by: { $0.value < $1.value })?.key
    }

    private func heatColor(for value: Double) -> Color {
        Theme.heatColor(fraction: value)
    }

    private func weekdayFullName(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][max(0, min(weekday - 1, 6))]
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let tileW = (geo.size.width - spacing * 6) / 7
            let avgs  = weekdayAverages
            let best  = bestWeekday
            let worst = worstWeekday

            VStack(spacing: 8) {
                HStack(spacing: spacing) {
                    ForEach(Array(displayOrder.enumerated()), id: \.offset) { idx, wd in
                        let value  = avgs[wd]
                        let isBest = wd == best && value != nil

                        VStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(value != nil ? heatColor(for: value!) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(
                                                value != nil ? Color.clear : Theme.border.opacity(0.45),
                                                lineWidth: 0.75
                                            )
                                    )
                                    .frame(width: tileW, height: 46)

                                if isBest {
                                    VStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                        Text(value != nil ? "\(Int(value! * 100))%" : "—")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .minimumScaleFactor(0.7)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text(value != nil ? "\(Int(value! * 100))%" : "—")
                                        .font(.system(
                                            size: value != nil ? 11 : 9,
                                            weight: .bold,
                                            design: .rounded
                                        ))
                                        .foregroundColor(
                                            value != nil
                                                ? .white.opacity(0.88)
                                                : Theme.text2.opacity(0.28)
                                        )
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }
                            }
                            .scaleEffect(appeared ? 1 : 0.65)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.62)
                                    .delay(Double(idx) * 0.055),
                                value: appeared
                            )

                            Text(dayLabels[idx])
                                .font(.system(size: 9, weight: isBest ? .black : .medium))
                                .foregroundColor(isBest ? Theme.accent : Theme.text2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                if let best = best, let bestVal = avgs[best] {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(Theme.accent)

                        Group {
                            if let worst = worst,
                               worst != best,
                               let worstVal = avgs[worst],
                               bestVal - worstVal > 0.08 {
                                Text("\(weekdayFullName(best))s are \(Int((bestVal - worstVal) * 100))% stronger than \(weekdayFullName(worst))s")
                            } else {
                                Text("Your performance is consistent across the week — well done")
                            }
                        }
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 4)
                    .animation(.easeOut(duration: 0.38).delay(0.48), value: appeared)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true }
        }
    }
}

// MARK: - SmoothLineChart

struct SmoothLineChart: View {
    let snapshots: [DailySnapshot]
    @State private var appear = false

    private var values: [Double] { snapshots.map(\.completionFraction) }

    static let axisFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private func axisLabel(for date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "Today" : Self.axisFormatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pts = points(w: w, h: h)

                ZStack(alignment: .bottomLeading) {
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        Path { p in
                            let y = h - CGFloat(level) * h * 0.88
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Theme.border, style: StrokeStyle(lineWidth: 0.5, dash: [3, 5]))
                    }

                    ForEach([25, 50, 75, 100], id: \.self) { pct in
                        let y = h - CGFloat(Double(pct) / 100) * h * 0.88
                        Text("\(pct)%")
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.text2)
                            .position(x: 14, y: y)
                    }

                    if pts.count >= 2 {
                        Path { p in
                            p.move(to: CGPoint(x: pts[0].x, y: h))
                            smoothPath(points: pts, path: &p)
                            p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: h))
                            p.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(appear ? 0.18 : 0), Theme.accent.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .animation(.easeOut(duration: 0.8), value: appear)

                        Path { p in
                            p.move(to: pts[0])
                            smoothPath(points: pts, path: &p)
                        }
                        .trim(from: 0, to: appear ? 1 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.coral, Theme.accent],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .animation(.easeOut(duration: 1.0), value: appear)

                        if let last = pts.last {
                            ZStack {
                                Circle().fill(Theme.accent.opacity(0.22)).frame(width: 12, height: 12)
                                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                            }
                            .shadow(color: Theme.accent.opacity(0.6), radius: 5)
                            .position(last)
                            .opacity(appear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.9), value: appear)
                        }
                    }
                }
            }

            if snapshots.count >= 2 {
                HStack {
                    // .first and .last are guaranteed non-nil by the count >= 2 guard above,
                    // but use optional chaining + fallback to be resilient against future refactors.
                    Text(axisLabel(for: snapshots.first?.date ?? Date()))
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                    Spacer()
                    if snapshots.count >= 7, let midSnap = snapshots[safe: snapshots.count / 2] {
                        Text(axisLabel(for: midSnap.date))
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                    Spacer()
                    Text(axisLabel(for: snapshots.last?.date ?? Date()))
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 3)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appear = true }
        }
    }

    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let step = w / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v) * h * 0.88)
        }
    }

    private func smoothPath(points pts: [CGPoint], path: inout Path) {
        guard pts.count >= 2 else { return }
        for i in 1..<pts.count {
            let prev = pts[i - 1], curr = pts[i]
            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) / 3, y: prev.y)
            let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) / 3, y: curr.y)
            path.addCurve(to: curr, control1: cp1, control2: cp2)
        }
    }
}

// MARK: - AnalyticsListPickerSheet
// Local picker — sets selectedListID binding without touching vm.activeListID

struct AnalyticsListPickerSheet: View {
    @Binding var selectedListID: UUID?
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                VStack(spacing: 0) {
                    Capsule().fill(Theme.bg3).frame(width: 36, height: 4)
                        .padding(.top, 12).padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Analytics For").font(.system(size: 22, weight: .black)).foregroundColor(Theme.text0)
                        Text("Data stays on this screen only").font(.system(size: 13)).foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 20)

                    let liveLists = vm.lists.filter { !$0.isArchived }
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(liveLists) { list in
                                Button(action: { selectedListID = list.id; dismiss() }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selectedListID == list.id ? Theme.accent.opacity(0.15) : Theme.bg2)
                                                .frame(width: 46, height: 46)
                                            Text(list.emoji).font(.title3)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(list.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text0)
                                            Text("\(list.tasks.count) tasks").font(.system(size: 12)).foregroundColor(Theme.text1)
                                        }
                                        Spacer()
                                        if selectedListID == list.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20)).foregroundColor(Theme.accent)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(selectedListID == list.id ? Theme.accent.opacity(0.07) : Theme.bg1)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                    .strokeBorder(selectedListID == list.id ? Theme.accent.opacity(0.3) : Theme.border, lineWidth: 0.5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.bg0)
    }
}

// MARK: - NewUserBanner
// Shows on analytics screen for the first 7 days. Cycles through messages.
// Fades out on day 6-7. Tracks install date in UserDefaults.

struct NewUserBanner: View {
    @EnvironmentObject var vm: AppViewModel

    private static let installKey = "sortyd_install_date"

    private var daysSinceInstall: Int {
        if UserDefaults.standard.object(forKey: Self.installKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.installKey)
        }
        guard let d = UserDefaults.standard.object(forKey: Self.installKey) as? Date else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0)
    }

    private var daysClocked: Int {
        let cal = Calendar.current
        let uniqueDays = Set(vm.snapshots.filter { $0.completionFraction > 0 }.map { cal.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    private var hasOldData: Bool {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
        let cutoffDay = Calendar.current.startOfDay(for: cutoff)
        return vm.snapshots.contains { Calendar.current.startOfDay(for: $0.date) < cutoffDay }
    }

    var shouldShow: Bool { daysSinceInstall < 7 && !hasOldData }

    @State private var msgIndex = 0
    @State private var bannerOpacity: Double = 1

    private var messages: [String] {
        let day = daysSinceInstall + 1
        return [
            "🌱 Day \(day) of 7 — your journey just started with Sortyd",
            "Give Sortyd time to learn how you work",
            daysClocked > 0
                ? "\(daysClocked) day\(daysClocked == 1 ? "" : "s") clocked in so far — keep it up!"
                : "Complete tasks today to start tracking your progress",
            "Better insights unlock as more data builds",
            "Track consistently and your grade will reflect it ✨"
        ]
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)

                Text(messages[msgIndex])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .id(msgIndex)

                Spacer()

                Text("\(7 - daysSinceInstall)d left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.text2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.20), lineWidth: 0.5)
                    )
            )
            .opacity(bannerOpacity)
            .task {
                // Start fading on day 5+
                if daysSinceInstall >= 5 {
                    let targetOpacity = daysSinceInstall >= 6 ? 0.35 : 0.65
                    withAnimation(.easeOut(duration: 1.5).delay(4)) {
                        bannerOpacity = targetOpacity
                    }
                }
                // Cycle messages
                while true {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    withAnimation(.easeInOut(duration: 0.38)) {
                        msgIndex = (msgIndex + 1) % messages.count
                    }
                }
            }
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppViewModel())
        .environmentObject(ThemeManager.shared)
}
