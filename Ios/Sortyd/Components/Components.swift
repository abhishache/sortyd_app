// MARK: - Components.swift
// Sortyd v3 — Premium Dark Components (Performance-Optimised)

import SwiftUI

private let kDebugAllowPastEditing = false

// ══════════════════════════════════════════════
// MARK: DonutChartView — Glowing amber arc
// ══════════════════════════════════════════════

struct DonutChartView: View {
    let fraction: Double
    var size: CGFloat = 100
    var lineWidth: CGFloat = 10
    var animated: Bool = true
    
    @State private var drawn: Double = 0
    
    private var pct: Int { Int((fraction * 100).rounded()) }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.bg3, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: drawn)
                .stroke(Theme.accent.opacity(0.15), lineWidth: lineWidth + 6)
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
            Circle()
                .trim(from: 0, to: drawn)
                .stroke(
                    AngularGradient(
                        colors: [Theme.coral, Theme.accent, Theme.accent],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(pct)")
                    .font(.system(size: size * 0.29, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)
                Text("%")
                    .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { drawn = fraction; return }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { drawn = fraction }
        }
        .onChange(of: fraction) { _, v in
            withAnimation(.easeOut(duration: 0.35)) { drawn = v }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: MonthYear — Helper value type
// ══════════════════════════════════════════════

struct MonthYear: Equatable, Hashable {
    let year: Int
    let month: Int  // 1-based
    
    var date: Date {
        // Calendar.date(from:) is nil only for invalid year/month combinations;
        // fall back to the current date rather than crashing.
        Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
    }
    
    var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
    
    var shortYear: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }
    
    static var current: MonthYear {
        let c = Calendar.current
        let now = Date()
        return MonthYear(year: c.component(.year, from: now),
                         month: c.component(.month, from: now))
    }
    
    /// Most-recent first, going back `count` months
    static func pastMonths(count: Int = 24) -> [MonthYear] {
        let cal = Calendar.current
        let now = Date()
        return (0..<count).compactMap { offset in
            guard let d = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            return MonthYear(year: cal.component(.year, from: d),
                             month: cal.component(.month, from: d))
        }
    }
}

// ══════════════════════════════════════════════
// MARK: HeatmapCalendarView — month picker + day tap
// ══════════════════════════════════════════════

struct HeatmapCalendarView: View {
    let listID: UUID
    @EnvironmentObject var vm: AppViewModel

    @State private var selectedMonth: MonthYear = .current
    @State private var showMonthPicker   = false
    @State private var selectedDaySnap: DailySnapshot? = nil
    @State private var selectedDayDate: Date = Date()
    @State private var showDayDetail     = false
    @State private var showEmptyToast    = false

    private let dayLetters = ["S","M","T","W","T","F","S"]
    private let colGap: CGFloat  = 0
    private let vSpacing: CGFloat = 1

    @State private var cachedSnapshotMap: [String: DailySnapshot] = [:]
    @State private var cachedDays: [Date?] = []

    private var taskCount: Int {
        vm.lists.first(where: { $0.id == listID })?.tasks.count ?? 1
    }

    private var installDate: Date {
        let key = "sortyd_install_date"
        if let d = UserDefaults.standard.object(forKey: key) as? Date {
            return Calendar.current.startOfDay(for: d)
        }
        let now = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(Date(), forKey: key)
        return now
    }

    var body: some View {
        GeometryReader { geo in
            CalendarGrid(
                geo: geo,
                cachedDays: cachedDays,
                cachedSnapshotMap: cachedSnapshotMap,
                selectedMonth: $selectedMonth,
                showMonthPicker: $showMonthPicker,
                selectedDaySnap: $selectedDaySnap,
                selectedDayDate: $selectedDayDate,
                showDayDetail: $showDayDetail,
                showEmptyToast: $showEmptyToast,
                dayLetters: dayLetters,
                colGap: colGap,
                vSpacing: vSpacing,
                taskCount: taskCount,
                installDate: installDate
            )
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(selectedMonth: $selectedMonth)
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Theme.r32)
                .presentationBackground(Theme.bg0)
        }
        .sheet(isPresented: $showDayDetail, onDismiss: {
            withAnimation(.easeOut(duration: 0.3)) {
                selectedMonth = .current
            }
        }) {
            DayDetailSheet(
                initialSnapshot: selectedDaySnap,
                tappedDate: selectedDayDate,
                listID: listID,
                vm: vm,
                onGoToToday: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        selectedMonth = .current
                    }
                    vm.selectedTab = 0
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Theme.r32)
            .presentationBackground(Theme.bg0)
        }
        .onAppear {
            cachedSnapshotMap = buildSnapshotMap()
            cachedDays = buildDays()
        }
        .onChange(of: listID) { _, _ in
            cachedSnapshotMap = buildSnapshotMap()
            cachedDays = buildDays()
        }
        .onChange(of: selectedMonth) { _, _ in
            cachedDays = buildDays()
        }
        .onChange(of: vm.snapshots.count) { _, _ in
            cachedSnapshotMap = buildSnapshotMap()
        }
        .onChange(of: vm.snapshots.map { "\($0.id)\($0.completedTaskIDs.count)" }.joined()) { _, _ in
            cachedSnapshotMap = buildSnapshotMap()
        }
        .fullScreenCover(isPresented: $showEmptyToast) {
            GhostDayToast(onDismiss: {
                    showEmptyToast = false
                }, onGoToToday: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        selectedMonth = .current
                    }
                    vm.selectedTab = 0
                })
        }
    }
    
    private func snapForDate(_ date: Date, map: [String: DailySnapshot]) -> DailySnapshot? {
        let key = Calendar.current.startOfDay(for: date).timeIntervalSince1970.description
        return map[key]
    }
    
    private func buildSnapshotMap() -> [String: DailySnapshot] {
        let cal = Calendar.current
        var map = [String: DailySnapshot]()
        for snap in vm.snapshots where snap.listID == listID {
            let key = cal.startOfDay(for: snap.date).timeIntervalSince1970.description
            map[key] = snap
        }
        return map
    }
    
    private func buildDays() -> [Date?] {
        let cal = Calendar.current
        let comps = DateComponents(year: selectedMonth.year, month: selectedMonth.month)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading: [Date?] = Array(repeating: nil, count: cal.component(.weekday, from: first) - 1)
        let days: [Date?] = range.map { cal.date(byAdding: .day, value: $0 - 1, to: first) }
        return leading + days
    }
}

private struct CalendarGrid: View {
    let geo: GeometryProxy
    let cachedDays: [Date?]
    let cachedSnapshotMap: [String: DailySnapshot]
    @Binding var selectedMonth: MonthYear
    @Binding var showMonthPicker: Bool
    @Binding var selectedDaySnap: DailySnapshot?
    @Binding var selectedDayDate: Date
    @Binding var showDayDetail: Bool
    @Binding var showEmptyToast: Bool
    let dayLetters: [String]
    let colGap: CGFloat
    let vSpacing: CGFloat
    let taskCount: Int
    let installDate: Date

    private var cellSize: CGFloat {
        let availW  = geo.size.width
        let availH  = geo.size.height
        let cellByW = (availW - colGap * 6) / 7
        let nRows: CGFloat = 7
        let cellByH = (availH - 13 - vSpacing * nRows) / nRows
        return min(cellByW, cellByH) * 1.2
    }
    
    private var rows: [[Date?]] {
        let count = cachedDays.count
        return stride(from: 0, to: count, by: 7).map { i in
            Array(cachedDays[i ..< min(i + 7, count)])
        }
    }
    
    var body: some View {
        let availW = geo.size.width
        let availH = geo.size.height
        let cs = cellSize
        
        VStack(alignment: .leading, spacing: 0) {

            Spacer(minLength: 6)

            // ── Header ──────────────────────────────────
            HStack {
                Button { showMonthPicker = true } label: {
                    HStack(spacing: 4) {
                        Text(selectedMonth.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if selectedMonth != .current {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { selectedMonth = .current }
                    } label: {
                        Text("Today")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(selectedMonth.shortYear)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
            }
            .frame(height: 15)
            
            Spacer(minLength: vSpacing)
            
            // ── Day letters ──────────────────────────────
            HStack(spacing: 0) {
                ForEach(dayLetters.indices, id: \.self) { i in
                    Text(dayLetters[i])
                        .font(.system(size: max(7, cs * 0.34), weight: .medium))
                        .foregroundColor(Theme.text2)
                        .frame(width: cs, height: cs)
                    if i < 6 { Spacer(minLength: 0) }
                }
            }
            
            // ── Grid rows ────────────────────────────────
            ForEach(0..<6, id: \.self) { row in
                Spacer(minLength: vSpacing)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        if row < rows.count,
                           col < rows[row].count,
                           let date = rows[row][col] {
                            let snap = cachedSnapshotMap[
                                Calendar.current.startOfDay(for: date)
                                    .timeIntervalSince1970.description
                            ]
                            CircleHeatCell(date: date, snapshot: snap, size: cs, taskCount: taskCount, installDate: installDate)
                                .contentShape(Circle())
                                .onTapGesture {
                                    guard date <= Date() else { return }
                                    if snap != nil || kDebugAllowPastEditing {
                                        selectedDaySnap = snap
                                        selectedDayDate = Calendar.current.startOfDay(for: date)
                                        showDayDetail   = true
                                    } else {
                                        showEmptyToast = true
                                    }
                                }
                        } else {
                            Color.clear.frame(width: cs, height: cs)
                        }
                        if col < 6 { Spacer(minLength: 0) }
                    }
                }
            }
            
            // ── Performance legend ───────────────────────
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Text("Weak")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Theme.text2)
                let n = max(1, taskCount)
                HStack(spacing: 2) {
                    ForEach(1...n, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.heatColorRG(fraction: Double(i) / Double(n), taskCount: n))
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                Text("Best")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Theme.text2)
            }
            .frame(width: availW * 0.7)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 2)
        }
        .frame(width: availW, height: availH)
    }
}

// ══════════════════════════════════════════════
// MARK: MonthPickerSheet
// ══════════════════════════════════════════════

struct MonthPickerSheet: View {
    @Binding var selectedMonth: MonthYear
    @Environment(\.dismiss) var dismiss
    
    private let months = MonthYear.pastMonths(count: 24)
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.bg3)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            Text("SELECT MONTH")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.6)
                .foregroundColor(Theme.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(months, id: \.self) { month in
                        HStack {
                            Text(month.label)
                                .font(.system(size: 15,
                                              weight: selectedMonth == month ? .bold : .regular))
                                .foregroundColor(selectedMonth == month ? Theme.accent : Theme.text0)
                            
                            Spacer()
                            
                            if month == .current {
                                Text("current")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Theme.text2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Theme.bg3))
                                    .padding(.trailing, selectedMonth == month ? 8 : 0)
                            }
                            
                            if selectedMonth == month {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedMonth == month
                                      ? Theme.accent.opacity(0.08)
                                      : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            selectedMonth == month
                                            ? Theme.accent.opacity(0.25)
                                            : Color.clear,
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedMonth = month
                            }
                            dismiss()
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 28)
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: DayDetailSheet
// ══════════════════════════════════════════════

struct DayDetailSheet: View {
    let initialSnapshot: DailySnapshot?
    let tappedDate: Date
    let listID: UUID
    @ObservedObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    /// Called when the user taps "Got it" on the cheat popup — navigates home to today
    var onGoToToday: (() -> Void)? = nil
    
    // ── Local state: tapping only flips this Set — no vm writes, no re-renders ──
    @State private var localCompletedIDs: Set<UUID> = []
    @State private var showCheatAlert = false
    
    /// Always the tapped day — stable, never derived from snapshot.
    private var sheetDate: Date {
        Calendar.current.startOfDay(for: tappedDate)
    }
    
    /// Used only to seed localCompletedIDs on appear and to get the snapshot id on flush.
    private var snapshot: DailySnapshot? {
        vm.snapshots.first(where: {
            $0.listID == listID &&
            Calendar.current.isDate($0.date, inSameDayAs: sheetDate)
        })
    }
    
    private var list: TaskList? { vm.lists.first(where: { $0.id == listID }) }
    
    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: sheetDate)
    }
    
    // ── These now read from localCompletedIDs, so they update instantly on tap ──
    private var completedTasks: [SortydTask] {
        guard let list = list else { return [] }
        return list.tasks.filter { localCompletedIDs.contains($0.id) }
    }
    
    private var missedTasks: [SortydTask] {
        guard let list = list else { return list?.tasks ?? [] }
        return list.tasks.filter { !localCompletedIDs.contains($0.id) }
    }
    
    private var pct: Int {
        guard let list = list, !list.tasks.isEmpty else { return 0 }
        return Int((Double(localCompletedIDs.count) / Double(list.tasks.count)) * 100)
    }
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    Text(dateLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1.6)
                        .foregroundColor(Theme.text2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    if snapshot != nil || kDebugAllowPastEditing {
                        // Score ring + label
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.12))
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                                    .frame(width: 72, height: 72)
                                VStack(spacing: -1) {
                                    Text("\(pct)")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.accent)
                                    Text("%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.accent.opacity(0.7))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(performanceLabel(pct))
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(Theme.text0)
                                Text("\(completedTasks.count) of \(completedTasks.count + missedTasks.count) tasks completed")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text2)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        
                        if snapshot == nil && kDebugAllowPastEditing {
                            if let list = list, !list.tasks.isEmpty {
                                taskGroup(title: "TASKS (DEBUG — NO DATA)", tasks: list.tasks)
                            } else {
                                EmptyDark(icon: "🛠️", title: "Debug Mode", subtitle: "No tasks found for this list.")
                                    .padding(.top, 16)
                            }
                        } else {
                            if !completedTasks.isEmpty {
                                taskGroup(title: "COMPLETED", tasks: completedTasks)
                            }
                            if !missedTasks.isEmpty {
                                taskGroup(title: "MISSED", tasks: missedTasks)
                            }
                        }
                        
                    } else {
                        EmptyDark(
                            icon: "📭",
                            title: "No data",
                            subtitle: "No performance was recorded\nfor this day."
                        )
                        .padding(.top, 16)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: showCheatAlert)
        .fullScreenCover(isPresented: $showCheatAlert) {
            CheatBlockPopup {
                showCheatAlert = false
                let total = list?.tasks.count ?? 1
                let updated = DailySnapshot(
                    id: snapshot?.id ?? UUID(),
                    date: sheetDate,
                    listID: listID,
                    completionFraction: Double(localCompletedIDs.count) / Double(total),
                    completedTaskIDs: Array(localCompletedIDs)
                )
                vm.upsertSnapshot(updated)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    dismiss()
                    onGoToToday?()
                }
            }
        }
        .onAppear {
            localCompletedIDs = Set(snapshot?.completedTaskIDs ?? [])
        }
        .onDisappear {
            let total = list?.tasks.count ?? 1
            let updated = DailySnapshot(
                id: snapshot?.id ?? UUID(),
                date: sheetDate,
                listID: listID,
                completionFraction: Double(localCompletedIDs.count) / Double(total),
                completedTaskIDs: Array(localCompletedIDs)
            )
            vm.upsertSnapshot(updated)
        }
    }
    
    @ViewBuilder
    private func taskGroup(title: String, tasks: [SortydTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(Theme.text2)
                Text("\(tasks.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(localCompletedIDs.isEmpty ? Theme.text2 : Theme.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(localCompletedIDs.isEmpty ? Theme.bg3 : Theme.accent.opacity(0.15)))
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    let isChecked = localCompletedIDs.contains(task.id)
                    
                    HStack(spacing: 12) {
                        Text(task.title)
                            .font(.system(size: 14, weight: isChecked ? .regular : .medium))
                            .foregroundColor(isChecked ? Theme.text2 : Theme.text0)
                            .strikethrough(isChecked, color: Theme.text2)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .strokeBorder(isChecked ? Theme.accent : Theme.border, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if isChecked {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color(hex: "#0A1A0A"))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard kDebugAllowPastEditing else {
                            showCheatAlert = true
                            return
                        }
                        if isChecked {
                            localCompletedIDs.remove(task.id)
                        } else {
                            localCompletedIDs.insert(task.id)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isChecked ? Theme.accent.opacity(0.05) : Theme.bg1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isChecked ? Theme.accent.opacity(0.15) : Theme.border,
                                                  lineWidth: 0.5)
                            )
                    )
                    .cardShadow()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
    }
    
    private func performanceLabel(_ pct: Int) -> String {
        switch pct {
        case 100:    return "Perfect day 🏆"
        case 75...:  return "Strong day 💪"
        case 50...:  return "Half-way there"
        case 25...:  return "Tough day"
        default:     return "No tasks done"
        }
    }
}

// ══════════════════════════════════════════════
// MARK: CircleHeatCell (private)
// ══════════════════════════════════════════════

private struct CircleHeatCell: View {
    let date: Date
    let snapshot: DailySnapshot?
    let size: CGFloat
    let taskCount: Int
    let installDate: Date

    private var frac: Double       { snapshot?.completionFraction ?? 0 }
    private var isToday: Bool      { Calendar.current.isDateInToday(date) }
    private var isFuture: Bool     { date > Date() && !Calendar.current.isDateInToday(date) }
    private var isInstallDay: Bool { Calendar.current.isDate(date, inSameDayAs: installDate) }
    private var day: String        { "\(Calendar.current.component(.day, from: date))" }
    
    @State private var glowPulse: Bool = false
    @State private var sparkRotation: Double = 0
    
    var body: some View {
        ZStack {
            // ── Base fill ──
            Circle()
                .fill(isFuture
                      ? Theme.bg2.opacity(0.4)
                      : frac == 0 ? Theme.text0.opacity(0.15) : Theme.heatColorRG(fraction: frac, taskCount: taskCount))
                .frame(width: size, height: size)

            // ── Day number ──
            Text(day)
                .font(.system(size: max(size * 0.36, 7),
                              weight: isToday ? .bold : .regular))
                .foregroundColor(
                    isFuture ? Theme.text0.opacity(0.18) :
                        frac >= 0.75 ? .white :
                        frac > 0     ? Theme.text0 : Theme.text0.opacity(0.6)
                )
        }
        .frame(width: size, height: size)
        // ── Glow rings rendered as overlay so they escape the layout frame ──
        .overlay {
            if isToday {
                ZStack {
                    // Outer soft ambient glow pulse
                    Circle()
                        .fill(Theme.accent.opacity(glowPulse ? 0.16 : 0.06))
                        .frame(width: size * 1.9, height: size * 1.9)
                        .blur(radius: size * 0.28)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
                    
                    // Mid glow bloom
                    Circle()
                        .fill(Theme.accent.opacity(glowPulse ? 0.24 : 0.08))
                        .frame(width: size * 1.42, height: size * 1.42)
                        .blur(radius: size * 0.14)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2), value: glowPulse)
                    
                    // Rotating dashed arc — amber sparks
                    Circle()
                        .trim(from: 0.0, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.accent.opacity(0.0), Theme.accent.opacity(0.9), Theme.accent.opacity(0.0)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2.5, 4.0])
                        )
                        .frame(width: size * 1.32, height: size * 1.32)
                        .rotationEffect(.degrees(sparkRotation))
                    
                    // Counter-rotating arc — coral sparks
                    Circle()
                        .trim(from: 0.0, to: 0.45)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.coral.opacity(0.0), Theme.coral.opacity(0.65), Theme.coral.opacity(0.0)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1.8, 6.0])
                        )
                        .frame(width: size * 1.18, height: size * 1.18)
                        .rotationEffect(.degrees(-sparkRotation * 0.65))
                    
                    // Hard accent border ring (angular gradient for lit look)
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [Theme.accent, Theme.coral.opacity(0.7), Theme.accent.opacity(0.5), Theme.accent],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: size, height: size)
                }
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if isInstallDay && !isFuture {
                InstallDayFlag(size: size)
                    .offset(x: 0, y: -(size * 0.72))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            guard isToday else { return }
            glowPulse = true
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                sparkRotation = 360
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: InstallDayFlag
// ══════════════════════════════════════════════

private struct InstallDayFlag: View {
    let size: CGFloat
    private let green = Color(hex: "#22C55E")

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(green)
                    .frame(width: size * 0.52, height: size * 0.22)
                Text("DAY 1")
                    .font(.system(size: max(4, size * 0.13), weight: .black))
                    .foregroundColor(.white)
                    .padding(.leading, 2)
            }
            .padding(.leading, 1)
            Rectangle()
                .fill(green.opacity(0.75))
                .frame(width: 1.5, height: size * 0.5)
                .padding(.leading, 1)
        }
        .frame(width: size, alignment: .leading)
    }
}

// ══════════════════════════════════════════════
// MARK: GlowStatCard
// ══════════════════════════════════════════════

struct GlowStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var gradient: LinearGradient = Theme.amberGlow
    var icon: String = "chart.line.uptrend.xyaxis"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gradient)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.text2)
                    .tracking(1.2)
            }
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(gradient)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.text2)
        }
        .padding(Theme.s16)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5))
        )
        .cardShadow()
    }
}

// ══════════════════════════════════════════════
// MARK: SectionLabel
// ══════════════════════════════════════════════

struct SectionLabel: View {
    let title: String
    var badge: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.text0)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(Theme.accent.opacity(0.15)))
            }
            Spacer()
            if let label = actionLabel {
                Button(action: { action?() }) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: EmptyDark
// ══════════════════════════════════════════════

struct EmptyDark: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: Theme.s16) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 76, height: 76)
                Circle().strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1).frame(width: 76, height: 76)
                Text(icon).font(.system(size: 32))
            }
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.text0)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(Theme.text2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(Theme.s32)
        .frame(maxWidth: .infinity)
    }
}

// ══════════════════════════════════════════════
// MARK: GhostDayToast — empty day nudge
// ══════════════════════════════════════════════

struct GhostDayToast: View {
    let onDismiss: () -> Void
    var onGoToToday: (() -> Void)? = nil
    
    private let messages: [(emoji: String, headline: String, body: String)] = [
        ("👻", "Looks like a ghost town.", "Nothing here — guess you didn't clock in."),
        ("🌑", "Total blackout.", "No data for this day. Maybe tomorrow?"),
        ("🕳️", "A void. Pure nothing.", "Seems like you skipped this one entirely."),
    ]
    
    @State private var pick = Int.random(in: 0..<3)
    
    // ── Blob animation ──
    @State private var blob1Offset: CGSize = .init(width: -30, height: 20)
    @State private var blob2Offset: CGSize = .init(width: 40, height: -10)
    @State private var blob3Offset: CGSize = .init(width: -10, height: -30)
    @State private var blobScale: CGFloat  = 0.6
    @State private var blobOpacity: Double = 0
    
    // ── Content animation ──
    @State private var emojiScale: CGFloat  = 0.3
    @State private var emojiOpacity: Double = 0
    @State private var emojiWiggle: Double  = 0
    @State private var textOffset: CGFloat  = 24
    @State private var textOpacity: Double  = 0
    @State private var particles: [GhostParticle] = GhostParticle.generate(count: 8)
    
    var body: some View {
        ZStack {
            // ── Dark scrim — tap anywhere to dismiss ──
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { dismissToast() }
            
            // ── Gradient blobs ──
            ZStack {
                // Blob A — accent
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.32), Theme.accent.opacity(0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 150
                        )
                    )
                    .frame(width: 380, height: 340)
                    .offset(blob1Offset)
                    .blur(radius: 4)
                
                // Blob B — coral tint
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.coral.opacity(0.24), Theme.coral.opacity(0)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 120
                        )
                    )
                    .frame(width: 300, height: 260)
                    .offset(blob2Offset)
                    .blur(radius: 6)
                
                // Blob C — dark center for readability
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#0D1F0D").opacity(0.85), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 220
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(blob3Offset)
            }
            .scaleEffect(blobScale)
            .opacity(blobOpacity)
            
            // ── Content — no background box ──
            VStack(spacing: 0) {
                Spacer()
                
                // Emoji + particles
                ZStack {
                    ForEach(particles) { p in
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: p.size, height: p.size)
                            .offset(x: p.x, y: p.offsetY)
                            .opacity(p.opacity)
                    }
                    
                    Text(messages[pick].emoji)
                        .font(.system(size: 44))
                        .scaleEffect(emojiScale)
                        .opacity(emojiOpacity)
                        .rotationEffect(.degrees(emojiWiggle))
                        .shadow(color: Theme.accent.opacity(0.6), radius: 20, x: 0, y: 0)
                }
                .frame(width: 140, height: 140)
                .padding(.bottom, 16)
                
                // Headline
                Text(messages[pick].headline)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                // Body
                Text(messages[pick].body)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                Spacer()
                
                Button(action: dismissToast) {
                    Text("Alrighty !!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#0A1A0A"))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Theme.accent)
                                .shadow(color: Theme.accent.opacity(0.5), radius: 14, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 48)
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            runEntrance()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                dismissToast()
            }
        }
    }
    
    private func dismissToast() {
            withAnimation(.easeOut(duration: 0.45)) {
                blobOpacity  = 0
                blobScale    = 0.6
                emojiOpacity = 0
                textOpacity  = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onDismiss()
                onGoToToday?()
            }
        }
    
    private func runEntrance() {
        // Blobs expand in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            blobScale   = 1.0
            blobOpacity = 1.0
        }
        // Drift blobs
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true).delay(0.3)) {
            blob1Offset = .init(width: 20, height: -25)
        }
        withAnimation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true).delay(0.1)) {
            blob2Offset = .init(width: -35, height: 18)
        }
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true).delay(0.6)) {
            blob3Offset = .init(width: 15, height: 28)
        }
        
        // Emoji pops in
        withAnimation(.spring(response: 0.42, dampingFraction: 0.52).delay(0.12)) {
            emojiScale   = 1.0
            emojiOpacity = 1.0
        }
        // Wiggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) { emojiWiggle = -13 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) { emojiWiggle = 11 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.interpolatingSpring(stiffness: 320, damping: 10)) { emojiWiggle = 0 }
                }
            }
        }
        // Text slides up
        withAnimation(.easeOut(duration: 0.38).delay(0.28)) {
            textOffset  = 0
            textOpacity = 1
        }
        // Particles
        animateParticles()
        
    }
    
    private func animateParticles() {
        for i in particles.indices {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + delay) {
                withAnimation(.easeOut(duration: 1.5)) {
                    particles[i].offsetY = -65
                    particles[i].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1 + delay) {
                particles[i].offsetY = 0
                particles[i].opacity = 0.9
                withAnimation(.easeOut(duration: 1.5)) {
                    particles[i].offsetY = -65
                    particles[i].opacity = 0
                }
            }
        }
    }
}

private struct GhostParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var size: CGFloat
    var offsetY: CGFloat = 0
    var opacity: Double  = 0.9
    
    static func generate(count: Int) -> [GhostParticle] {
        (0..<count).map { _ in
            GhostParticle(
                x: CGFloat.random(in: -55...55),
                size: CGFloat.random(in: 3...7)
            )
        }
    }
}

// ══════════════════════════════════════════════
// MARK: CheatBlockPopup — borderless gradient blob
// ══════════════════════════════════════════════

struct CheatBlockPopup: View {
    let onDismiss: () -> Void
    
    private let messages: [(emoji: String, headline: String, body: String)] = [
        ("🕵️", "Nice try, cheater!", "We see you trying to rewrite history.\nThe past is locked — go crush tomorrow instead."),
        ("🔒", "Nope. Not today.", "Sorry, we can't let you cheat for your own good.\nFocus on tomorrow, not fixing yesterday."),
        ("😤", "History is sealed!", "What's done is done.\nChannel that energy into making today count."),
        ("🚫", "Time machine? Denied.", "We want you to get better tomorrow,\nnot waste time polishing the past."),
    ]
    
    @State private var pick = Int.random(in: 0..<4)
    
    // ── Gradient blob animation ──
    @State private var blob1Offset: CGSize = .init(width: -30, height: 20)
    @State private var blob2Offset: CGSize = .init(width: 40, height: -10)
    @State private var blob3Offset: CGSize = .init(width: -10, height: -30)
    @State private var blobScale: CGFloat  = 0.6
    @State private var blobOpacity: Double = 0
    
    // ── Content animation ──
    @State private var lockScale: CGFloat  = 0.3
    @State private var lockOpacity: Double = 0
    @State private var lockWiggle: Double  = 0
    @State private var textOffset: CGFloat = 24
    @State private var textOpacity: Double = 0
    @State private var btnOpacity: Double  = 0
    @State private var btnOffset: CGFloat  = 16
    @State private var particles: [CheatParticle] = CheatParticle.generate(count: 10)
    
    var body: some View {
        ZStack {
            // ── Soft dark scrim — no hard edges ──
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // ── Gradient blobs — uneven, organic, no box ──
            ZStack {
                // Blob A — amber/coral
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.38), Theme.accent.opacity(0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .frame(width: 400, height: 360)
                    .offset(blob1Offset)
                    .blur(radius: 2)
                
                // Blob B — coral tint offset
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.coral.opacity(0.28), Theme.coral.opacity(0)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 130
                        )
                    )
                    .frame(width: 340, height: 280)
                    .offset(blob2Offset)
                    .blur(radius: 6)
                
                // Blob C — deep center fill so text is readable
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#0D1F0D").opacity(0.88), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 240
                        )
                    )
                    .frame(width: 420, height: 420)
                    .offset(blob3Offset)
            }
            .scaleEffect(blobScale)
            .opacity(blobOpacity)
            
            // ── Content — no background, no border, no box ──
            VStack(spacing: 0) {
                
                Spacer()
                
                // Animated emoji + floating particles
                ZStack {
                    ForEach(particles) { p in
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: p.size, height: p.size)
                            .offset(x: p.x, y: p.offsetY)
                            .opacity(p.opacity)
                    }
                    
                    Text(messages[pick].emoji)
                        .font(.system(size: 44))
                        .scaleEffect(lockScale)
                        .opacity(lockOpacity)
                        .rotationEffect(.degrees(lockWiggle))
                        .shadow(color: Theme.accent.opacity(0.6), radius: 20, x: 0, y: 0)
                }
                .frame(width: 140, height: 140)
                .padding(.bottom, 16)
                
                // Headline
                Text(messages[pick].headline)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                // Body
                Text(messages[pick].body)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 0)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                Spacer()
                
                // CTA — capsule pill, no enclosing box
                Button(action: onDismiss) {
                    Text("Got it, I'll do better 💪")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#0A1A0A"))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Theme.accent)
                                .shadow(color: Theme.accent.opacity(0.5), radius: 14, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .offset(y: btnOffset)
                .opacity(btnOpacity)
                .padding(.bottom, 48)
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear { runEntrance() }
    }
    
    // ── Entrance sequence ──
    private func runEntrance() {
        // Blobs expand in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            blobScale   = 1.0
            blobOpacity = 1.0
        }
        // Drift blobs continuously for organic feel
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true).delay(0.3)) {
            blob1Offset = .init(width: 20, height: -25)
        }
        withAnimation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true).delay(0.1)) {
            blob2Offset = .init(width: -35, height: 18)
        }
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true).delay(0.6)) {
            blob3Offset = .init(width: 15, height: 28)
        }
        
        // Lock emoji pops in
        withAnimation(.spring(response: 0.42, dampingFraction: 0.52).delay(0.12)) {
            lockScale   = 1.0
            lockOpacity = 1.0
        }
        // Wiggle after landing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) { lockWiggle = -13 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) { lockWiggle = 11 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.interpolatingSpring(stiffness: 320, damping: 10)) { lockWiggle = 0 }
                }
            }
        }
        // Text slides up
        withAnimation(.easeOut(duration: 0.38).delay(0.28)) {
            textOffset  = 0
            textOpacity = 1
        }
        // Button slides up
        withAnimation(.easeOut(duration: 0.38).delay(0.42)) {
            btnOffset  = 0
            btnOpacity = 1
        }
        // Particles
        animateParticles()
    }
    
    private func animateParticles() {
        for i in particles.indices {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + delay) {
                withAnimation(.easeOut(duration: 1.5)) {
                    particles[i].offsetY = -65
                    particles[i].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1 + delay) {
                particles[i].offsetY = 0
                particles[i].opacity = 0.9
                withAnimation(.easeOut(duration: 1.5)) {
                    particles[i].offsetY = -65
                    particles[i].opacity = 0
                }
            }
        }
    }
}

// ── Particle model ──
private struct CheatParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var size: CGFloat
    var offsetY: CGFloat = 0
    var opacity: Double  = 0.9
    
    static func generate(count: Int) -> [CheatParticle] {
        (0..<count).map { _ in
            CheatParticle(
                x: CGFloat.random(in: -55...55),
                size: CGFloat.random(in: 3...7)
            )
        }
    }
}
