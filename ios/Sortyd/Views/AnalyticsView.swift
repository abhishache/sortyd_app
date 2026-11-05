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

    private var resolvedListID: UUID {
        selectedListID
            ?? vm.lists.first(where: { $0.id == vm.activeListID && !$0.isTodo && !$0.isWeekly })?.id
            ?? vm.lists.first(where: { !$0.isArchived && !$0.isTodo && !$0.isWeekly })?.id
            ?? UUID()
    }

    enum Period: String, CaseIterable {
        case week  = "7D"
        case month = "30D"
        case all   = "ALL"
    }

    private var installDate: Date {
        let key = "sortyd_install_date"
        let cal = Calendar.current
        let stored = (UserDefaults.standard.object(forKey: key) as? Date).map { cal.startOfDay(for: $0) }
        if stored == nil { UserDefaults.standard.set(Date(), forKey: key) }

        let earliestSnapshot = vm.snapshots.map { cal.startOfDay(for: $0.date) }.min()
        let earliestList = vm.lists.map { cal.startOfDay(for: $0.createdAt) }.min()
        return [stored, earliestSnapshot, earliestList].compactMap { $0 }.min()
            ?? cal.startOfDay(for: Date())
    }

    private var installedDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return max(1, (cal.dateComponents([.day], from: installDate, to: today).day ?? 0) + 1)
    }

    // One install-anchored period window for every Analytics visual.
    // 30D and ALL match until the app has more than 30 installed days.
    private var periodSnaps: [DailySnapshot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let all = vm.snapshotsForList(id: resolvedListID)
        var lookup: [Date: DailySnapshot] = [:]
        for s in all { lookup[cal.startOfDay(for: s.date)] = s }
        switch period {
        case .week:  return filledDays(count: min(7, installedDays), endingOn: today, lookup: lookup)
        case .month: return filledDays(count: min(30, installedDays), endingOn: today, lookup: lookup)
        case .all:   return filledDays(count: installedDays, endingOn: today, lookup: lookup)
        }
    }

    // Shared by score, trend, heatmap, Task DNA, and Needs Work.
    private var snaps: [DailySnapshot] {
        periodSnaps
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

    struct TrendPoint: Identifiable {
        let id = UUID()
        var date: Date
        var completionFraction: Double
        var axisLabel: String?
    }

    private var usesWeeklyAllTrend: Bool {
        period == .all && installedDays > 3
    }

    private var trendPoints: [TrendPoint] {
        if usesWeeklyAllTrend {
            return weeklyTrendPoints(from: periodSnaps)
        }
        return snaps.enumerated().map { idx, snap in
            let isLastToday = idx == snaps.count - 1 && Calendar.current.isDateInToday(snap.date)
            return TrendPoint(
                date: snap.date,
                completionFraction: snap.completionFraction,
                axisLabel: isLastToday ? localizedTodayLabel : nil
            )
        }
    }

    private func weeklyTrendPoints(from snapshots: [DailySnapshot]) -> [TrendPoint] {
        guard !snapshots.isEmpty else { return [] }
        return stride(from: 0, to: snapshots.count, by: 7).map { start in
            let end = min(start + 7, snapshots.count)
            let bucket = Array(snapshots[start..<end])
            let avg = bucket.map(\.completionFraction).reduce(0, +) / Double(bucket.count)
            let isLast = end == snapshots.count
            return TrendPoint(
                date: bucket.last?.date ?? Date(),
                completionFraction: avg,
                axisLabel: isLast ? localizedTodayLabel : localizedWeekLabel((start / 7) + 1)
            )
        }
    }

    private var localizedTodayLabel: String {
        return vm.localized("Today")
    }

    private func localizedWeekLabel(_ number: Int) -> String {
        return String(format: vm.localized("W%lld"), Int64(number))
    }

    private var avg: Int {
        CompletionPolicy.percentage(CompletionPolicy.average(snaps.map(\.completionFraction)))
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
        case 90...100: return vm.localized("Exceptional")
        case 80..<90:  return vm.localized("Great work")
        case 75..<80:  return vm.localized("Almost there")
        case 70..<75:  return vm.localized("On track")
        case 60..<70:  return vm.localized("Room to grow")
        case 50..<60:  return vm.localized("Keep pushing")
        default:       return vm.localized("Just starting")
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
        let n = snaps.count
        guard n > 0, let first = snaps.first else { return nil }
        let cal = Calendar.current
        let currentStart = cal.startOfDay(for: first.date)
        guard let previousEnd = cal.date(byAdding: .day, value: -1, to: currentStart),
              previousEnd >= installDate else { return nil }
        guard let previousStart = cal.date(byAdding: .day, value: -(n - 1), to: previousEnd) else { return nil }
        let clampedStart = max(previousStart, installDate)
        let previousDays = max(1, (cal.dateComponents([.day], from: clampedStart, to: previousEnd).day ?? 0) + 1)
        let all = vm.snapshotsForList(id: resolvedListID)
        var lookup: [Date: DailySnapshot] = [:]
        for snap in all { lookup[cal.startOfDay(for: snap.date)] = snap }
        let prevSnaps = filledDays(count: previousDays, endingOn: previousEnd, lookup: lookup)
        guard !prevSnaps.isEmpty else { return nil }
        let previousPercentage = CompletionPolicy.percentage(CompletionPolicy.average(prevSnaps.map(\.completionFraction)))
        return avg - previousPercentage
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
        let f = DateFormatter()
        f.locale = vm.appLanguage.locale
        return f.shortWeekdaySymbols[max(0, min(weekday - 1, 6))]
    }

    // MARK: - Task DNA helpers

    struct TaskDNAItem: Identifiable {
        var id: UUID
        var title: String
        var rate: Double   // 0–1 completion rate
        var streak: Int    // current streak days
    }

    struct TaskRecencyItem: Identifiable {
        var id: UUID
        var title: String
        var daysAgo: Int?
        var wasNeverDone: Bool = false
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

    private var taskRecencyItems: [TaskRecencyItem] {
        guard let list = vm.listForID(resolvedListID) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let allSnaps = vm.snapshotsForList(id: resolvedListID)

        return list.tasks.map { task in
            let lastDoneDate: Date?
            if task.isCompleted {
                lastDoneDate = today
            } else {
                lastDoneDate = allSnaps
                    .filter { $0.completedTaskIDs.contains(task.id) }
                    .map { cal.startOfDay(for: $0.date) }
                    .max()
            }

            let wasNeverDone = lastDoneDate == nil
            let referenceDate = lastDoneDate ?? cal.startOfDay(for: task.createdAt)
            let daysAgo = max(0, cal.dateComponents([.day], from: referenceDate, to: today).day ?? 0)
            return TaskRecencyItem(id: task.id, title: task.title, daysAgo: daysAgo, wasNeverDone: wasNeverDone)
        }
        .sorted {
            if ($0.daysAgo ?? 0) == ($1.daysAgo ?? 0) {
                return $0.title < $1.title
            }
            return ($0.daysAgo ?? 0) > ($1.daysAgo ?? 0)
        }
    }

    private var coldTaskRecencyItems: [TaskRecencyItem] {
        taskRecencyItems.filter { ($0.daysAgo ?? 0) > 0 }
    }

    private var overdueRecencyItems: [TaskRecencyItem] {
        taskRecencyItems.filter { ($0.daysAgo ?? 0) >= 3 }
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

                        if !overdueRecencyItems.isEmpty {
                            taskRecencyCard
                                .padding(.horizontal, Theme.s16)
                                .padding(.bottom, 10)
                        }

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

                        Spacer(minLength: 140)
                    }
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await vm.refresh() }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if selectedListID == nil {
                selectedListID = vm.lists.first(where: { $0.id == vm.activeListID && !$0.isTodo && !$0.isWeekly })?.id
                             ?? vm.lists.first(where: { !$0.isArchived && !$0.isTodo && !$0.isWeekly })?.id
            }
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "analytics",
                AnalyticsParameterScreenClass: "AnalyticsView"
            ])
            guard !heroAppeared else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    heroAppeared = true
                }
            }
        }
        .onChange(of: selectedListID) { oldValue, newValue in
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
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(vm.localized("ANALYTICS"))
                    .font(.system(size: 8, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(Theme.text2.opacity(0.7))
                Text(vm.localized("Report"))
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Theme.text0)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 8) {
                periodSelector
                listPickerButton
            }
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

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 18) {
                        heroStat(label: vm.localized("AVG"), value: "\(avg)", unit: "%", color: Theme.text0)
                        heroStat(label: vm.localized("STREAK"), value: "\(bestStreakForPeriod)", unit: "d", color: Theme.coral)
                    }

                    heroVsLastPill
                }
                .padding(.trailing, Theme.s16)
                .padding(.top, 10)
                .padding(.bottom, Theme.s16)
            }
        }
        .dualGlow(violetIntensity: 0.14, cyanIntensity: 0.08)
    }

    private var heroVsLastPill: some View {
        let color = (vsLastPeriod ?? 0) >= 0 ? Theme.accent : Theme.danger
        return HStack(spacing: 5) {
            if let vs = vsLastPeriod {
                Image(systemName: vs >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .black))
                Text(vs >= 0 ? "+\(vs)%" : "\(vs)%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .monospacedDigit()
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .black))
                Text(vm.localized("N/A"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }

            Text(vm.localized("VS LAST"))
                .font(.system(size: 7, weight: .black))
                .kerning(1.1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.10)))
        .overlay(Capsule().strokeBorder(color.opacity(0.16), lineWidth: 0.5))
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
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
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
                Text(selectedList?.cleanName ?? vm.localized("No list"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text0)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.text2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 140, maxWidth: 200)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 0.75)
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

    // MARK: - Recovery Rail Card

    private var taskRecencyCard: some View {
        let items = overdueRecencyItems
        let leadColor = recencyColor(daysAgo: items.first?.daysAgo)
        return VStack(alignment: .leading, spacing: 10) {

            // ── Compact header ────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: (items.first?.daysAgo ?? 0) >= 5 ? "exclamationmark.triangle.fill" : "bell.fill")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(leadColor)
                Text(recoveryQueueTitle)
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(Theme.text2)
                Text(overdueSummary)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor((items.first?.daysAgo ?? 0) >= 5 ? .white : leadColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((items.first?.daysAgo ?? 0) >= 5 ? leadColor : leadColor.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(leadColor.opacity(0.30), lineWidth: 0.5)
                    )
                Spacer()
                if let lead = items.first {
                    Text(recencyLabel(daysAgo: lead.daysAgo))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(leadColor)
                        .monospacedDigit()
                }
            }

            // ── Dormancy rows ─────────────────────────────────────
            VStack(spacing: 8) {
                ForEach(items.prefix(5)) { item in
                    dormancyRow(item)
                }
                if items.count > 5 {
                    Text(overdueMoreLabel(extra: items.count - 5))
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Theme.text2)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                    .fill(Theme.bg1)
                RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                    .fill(leadColor.opacity(0.06))
                RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                    .strokeBorder(leadColor.opacity(0.30), lineWidth: 0.8)
            }
        )
        .shadow(color: leadColor.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private func dormancyRow(_ item: TaskRecencyItem) -> some View {
        let color = recencyColor(daysAgo: item.daysAgo)
        let frac  = recencyHeatFraction(daysAgo: item.daysAgo)
        return HStack(spacing: 10) {
            // Task name
            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.text0)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Heat bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.bg3.opacity(0.40))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.70), color, color.opacity(0.80)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * frac))
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 0)
                }
            }
            .frame(width: 70, height: 6)

            // Day badge
            Text(recencyLabel(daysAgo: item.daysAgo))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var recoveryQueueTitle: String {
        return vm.localized("NEEDS ATTENTION")
    }

    private var recoveryQueueSubtitle: String {
        guard let first = coldTaskRecencyItems.first else {
            return vm.localized("Everything is moving")
        }

        let title = clippedAnalyticsTaskTitle(first.title, limit: 22)
        return String(format: vm.localized("Restart “%@” first"), title)
    }

    private var recoveryQueueHint: String {
        return vm.localized("One small log gets the rhythm back.")
    }

    private var coldRecencySummary: String {
        let count = coldTaskRecencyItems.count
        return String(format: vm.localized("%lld paused"), Int64(count))
    }

    private var overdueSummary: String {
        let count = overdueRecencyItems.count
        return String(format: vm.localized(count == 1 ? "1 thing" : "%lld things"), Int64(count))
    }

    private func overdueMoreLabel(extra: Int) -> String {
        return String(format: vm.localized(extra == 1 ? "+1 more thing" : "+%lld more things"), Int64(extra))
    }

    private func recencyColor(daysAgo: Int?) -> Color {
        guard let daysAgo else { return Color(hex: "#FF3B30") }
        // Urgency Spectrum: Yellow -> Orange -> Red -> Deep Red
        switch daysAgo {
        case 0...2: return Theme.accent // Should not happen in this view anymore, but for safety
        case 3:     return Color(hex: "#FFCC00") // Yellow (Warning)
        case 4:     return Color(hex: "#FF9500") // Orange (Action needed)
        case 5:     return Color(hex: "#FF3B30") // Red (Urgent)
        case 6:     return Color(hex: "#D70015") // Deep Red (Critical)
        default:    return Color(hex: "#AF0000") // Dark Red (Extreme)
        }
    }

    private func recencyHeatFraction(daysAgo: Int?) -> Double {
        guard let daysAgo else { return 1 }
        // Faster fill for urgency: 3 days starts at 40%, hits 100% at 7 days
        let adjustedDays = Double(max(0, daysAgo - 2))
        return min(1.0, 0.4 + (adjustedDays * 0.15))
    }

    private func recencyMicrocopy(for item: TaskRecencyItem) -> String {
        if item.wasNeverDone {
            return vm.localized("not started")
        }
        return vm.localized("quiet")
    }

    private func recencyShortLabel(daysAgo: Int?) -> String {
        guard let daysAgo else { return vm.localized("analytics_recency_new_lower") }
        return String(format: vm.localized("%lldd"), Int64(daysAgo))
    }

    private var restartCue: String {
        return vm.localized("restart")
    }

    private func recencyLabel(daysAgo: Int?) -> String {
        guard let daysAgo else { return vm.localized("analytics_recency_new_title") }
        if daysAgo == 0 { return localizedTodayLabel }
        if daysAgo == 1 { return vm.localized("Yesterday") }
        return String(format: vm.localized("%lldd"), Int64(daysAgo))
    }

    private func clippedAnalyticsTaskTitle(_ title: String, limit: Int) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(max(1, limit - 3))) + "..."
    }

    // MARK: - Recovery Rail Sub-Views

    // Recovery Rail inline helpers (RecoveryColdestRing and RecoveryTileView removed)

    // MARK: - Trend Chart Card (height reduced 10%: 126 → 114)

    private var trendChartTitle: String {
        switch period {
        case .week:  return vm.localized("7-DAY TREND")
        case .month: return vm.localized("30-DAY TREND")
        case .all:   return usesWeeklyAllTrend ? vm.localized("WEEKLY TREND") : vm.localized("ALL-TIME TREND")
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
                    Text(vm.localized("completion"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: trendChartTitle)

            SmoothLineChart(points: trendPoints)
                .frame(height: 114)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
                .id("\(period.rawValue)-\(usesWeeklyAllTrend)")
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
                    Text(vm.localized("DAY-OF-WEEK PATTERN"))
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.8)
                        .foregroundColor(Theme.text2)
                    Text(vm.localized("When you perform best"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text0.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 5) {
                    Text(vm.localized("LOW"))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.text2)
                    HStack(spacing: 2) {
                        ForEach([0.1, 0.35, 0.6, 0.85, 1.0], id: \.self) { intensity in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: intensity))
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text(vm.localized("HIGH"))
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

    private func dnaLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundColor(Theme.text2)
        }
    }

    private func heatmapColor(for intensity: Double) -> Color {
        Theme.heatColor(fraction: intensity)
    }

    // MARK: - Task DNA Card (replaces Momentum card)

    private var taskDNACard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.localized("TASK DNA"))
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.8)
                        .foregroundColor(Theme.text2)
                    Text(vm.localized("Per-task completion breakdown"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text0.opacity(0.40))
                }
                Spacer()
                // Inline legend (replaces consistency badge)
                HStack(spacing: 10) {
                    dnaLegendItem(color: Theme.accent,  label: "≥80%")
                    dnaLegendItem(color: Theme.warning, label: "60%+")
                    dnaLegendItem(color: Theme.coral,   label: "<60%")
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                            .foregroundColor(Theme.coral)
                        Text(vm.localized("3d+"))
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                }
            }

            let items = taskDNAItems
            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "dna")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.text2)
                    Text(vm.localized("No task data yet"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
                .frame(maxWidth: .infinity).frame(height: 60)
            } else {
                TaskDNAChart(items: items)
                    .frame(height: TaskDNAChart.chartHeight(for: items.count))
                    .id(period)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    ))
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: period)
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
                    Text(vm.localized("NEEDS WORK"))
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.6)
                        .foregroundColor(Theme.text2)
                }
                Spacer()
                let taskWord = weakTasks.count == 1 ? vm.localized("task") : vm.localized("tasks")
                Text("\(weakTasks.count) \(taskWord)")
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
                Text("\(CompletionPolicy.percentage(item.rate))")
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

    static let rowH: CGFloat    = 16
    static let rowSpacing: CGFloat = 5

    static func chartHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 40 }
        return CGFloat(count) * (rowH + rowSpacing) - rowSpacing
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let rowH   = Self.rowH
            let spacing = Self.rowSpacing
            let labelW: CGFloat = min(w * 0.30, 90)
            let scoreW: CGFloat = 36
            let flameW: CGFloat = 9
            let barZoneW = max(32, w - labelW - scoreW - flameW - 24)

            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.text0)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: labelW, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Theme.border.opacity(0.5))
                                .frame(height: rowH)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [barColor(for: item.rate), barColor(for: item.rate).opacity(0.55)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: appear ? barZoneW * CGFloat(item.rate) : 0, height: rowH)
                                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(idx) * 0.05), value: appear)
                        }
                        .frame(width: barZoneW, height: rowH)

                        Text("\(CompletionPolicy.percentage(item.rate))%")
                            .font(.system(size: 8.2, weight: .bold, design: .rounded))
                            .foregroundColor(barColor(for: item.rate))
                            .frame(width: scoreW, alignment: .trailing)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if item.streak >= 3 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7.5))
                                .foregroundColor(Theme.coral)
                                .frame(width: flameW)
                        } else {
                            Spacer().frame(width: flameW)
                        }
                    }
                    .frame(height: rowH)
                    .opacity(appear ? 1 : 0)
                    .offset(x: appear ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(Double(idx) * 0.05), value: appear)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appear = true }
        }
    }
}

// MARK: - WeekdayHeatmap

struct WeekdayHeatmap: View {
    @EnvironmentObject var vm: AppViewModel
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
                        let isWorst = wd == worst && value != nil && wd != best

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
                                        Text(value != nil ? "\(CompletionPolicy.percentage(value!))%" : "—")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .minimumScaleFactor(0.7)
                                            .lineLimit(1)
                                    }
                                } else if isWorst {
                                    VStack(spacing: 2) {
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(Theme.text2.opacity(0.75))
                                        Text(value != nil ? "\(CompletionPolicy.percentage(value!))%" : "—")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(.white.opacity(0.82))
                                            .minimumScaleFactor(0.7)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text(value != nil ? "\(CompletionPolicy.percentage(value!))%" : "—")
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
                                .font(.system(size: 9, weight: (isBest || isWorst) ? .black : .medium))
                                .foregroundColor(isBest ? Theme.accent : (isWorst ? Theme.text2.opacity(0.78) : Theme.text2))
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
                                Text(String(format: vm.localized("%@s are %lld%% stronger than %@s"), weekdayFullName(best), Int64((bestVal - worstVal) * 100), weekdayFullName(worst)))
                            } else {
                                Text(vm.localized("Your performance is consistent across the week — well done"))
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
    @EnvironmentObject var vm: AppViewModel
    let points: [AnalyticsView.TrendPoint]
    @State private var appear = false

    private var values: [Double] { points.map(\.completionFraction) }

    static let axisFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private func axisLabel(for point: AnalyticsView.TrendPoint) -> String {
        if let label = point.axisLabel { return label }
        Self.axisFormatter.locale = vm.appLanguage.locale
        return Calendar.current.isDateInToday(point.date) ? vm.localized("Today") : Self.axisFormatter.string(from: point.date)
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

            if points.count >= 2 {
                HStack {
                    // .first and .last are guaranteed non-nil by the count >= 2 guard above,
                    // but use optional chaining + fallback to be resilient against future refactors.
                    Text(axisLabel(for: points.first ?? AnalyticsView.TrendPoint(date: Date(), completionFraction: 0, axisLabel: nil)))
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                    Spacer()
                    if points.count >= 3, let midPoint = points[safe: points.count / 2] {
                        Text(axisLabel(for: midPoint))
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                    Spacer()
                    Text(axisLabel(for: points.last ?? AnalyticsView.TrendPoint(date: Date(), completionFraction: 0, axisLabel: nil)))
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
        guard !values.isEmpty else { return [] }
        if values.count == 1 {
            let y = h - CGFloat(values[0]) * h * 0.88
            return [CGPoint(x: 0, y: y), CGPoint(x: w, y: y)]
        }
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
                        Text(vm.localized("Analytics For")).font(.system(size: 22, weight: .black)).foregroundColor(Theme.text0)
                        Text(vm.localized("Data stays on this screen only")).font(.system(size: 13)).foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 20)

                    let liveLists = vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
                    let todoList  = vm.lists.first(where: { $0.isTodo })
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(liveLists) { list in
                                analyticsListRow(list, selectedListID: $selectedListID)
                            }
                            if let todo = todoList {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 0.5)
                                    .padding(.vertical, 4)
                                Text(vm.localized("ADHOC TO DO"))
                                    .font(.system(size: 9, weight: .bold))
                                    .kerning(1.5)
                                    .foregroundColor(Theme.text2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                analyticsListRow(todo, selectedListID: $selectedListID)
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

    @ViewBuilder
    private func analyticsListRow(_ list: TaskList, selectedListID: Binding<UUID?>) -> some View {
        Button(action: { selectedListID.wrappedValue = list.id; dismiss() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedListID.wrappedValue == list.id ? Theme.accent.opacity(0.15) : Theme.bg2)
                        .frame(width: 46, height: 46)
                    Text(list.emoji).font(.title3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(list.cleanName).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text0)
                    Text(String(format: list.tasks.count == 1 ? vm.localized("%lld task") : vm.localized("%lld tasks"), Int64(list.tasks.count))).font(.system(size: 12)).foregroundColor(Theme.text1)
                }
                Spacer()
                if selectedListID.wrappedValue == list.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(Theme.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectedListID.wrappedValue == list.id ? Theme.accent.opacity(0.07) : Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selectedListID.wrappedValue == list.id ? Theme.accent.opacity(0.3) : Theme.border, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
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
            vm.localized("🌱 Day %lld of 7 — your journey just started with Sortyd").replacingOccurrences(of: "%lld", with: "\(day)"),
            vm.localized("Give Sortyd time to learn how you work"),
            daysClocked > 0
                ? (daysClocked == 1
                   ? vm.localized("1 day clocked in so far — keep it up!")
                   : vm.localized("%lld days clocked in so far — keep it up!").replacingOccurrences(of: "%lld", with: "\(daysClocked)"))
                : vm.localized("Complete tasks today to start tracking your progress"),
            vm.localized("Better insights unlock as more data builds"),
            vm.localized("Track consistently and your grade will reflect it ✨")
        ]
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .fixedSize()

                Text(messages[msgIndex])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.38), value: msgIndex)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(7 - daysSinceInstall)\(vm.localized("d left"))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.text2)
                    .fixedSize()
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
                if daysSinceInstall >= 5 && bannerOpacity == 1 {
                    let target = daysSinceInstall >= 6 ? 0.35 : 0.65
                    withAnimation(.easeOut(duration: 1.5).delay(4)) {
                        bannerOpacity = target
                    }
                }
                while true {
                    do {
                        try await Task.sleep(nanoseconds: 3_500_000_000)
                    } catch {
                        return  // task cancelled (tab left) — exit cleanly, don't spin
                    }
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
