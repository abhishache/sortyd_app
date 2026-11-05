import SwiftUI

struct WeeklyPlannerSection: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var appearing = false
    @State private var selectedWeekStart = WeeklyPlan.currentWeekStart()
    
    @State private var selectedDate: Date? = nil
    @State private var newTaskTitle: String = ""
    @State private var showTaskEntry = false
    @State private var selectedHex: String = "#00E5FF"
    @State private var selectedDurationMinutes = 30
    @State private var editingTask: SortydTask? = nil
    @State private var editingListID: UUID? = nil
    
    private let rowHeight: CGFloat = 38
    private let taskColors = ["#00E5FF", "#6D5DF5", "#FF6B6B", "#4ECDC4", "#FFD93D"]
    private let durationOptions = [15, 30, 60]
    
    var body: some View {
        VStack(spacing: 0) {
            calendarHeader
                .frame(height: 46)
                .background(Theme.bg0)
            
            dateStrip
            plannerHint
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack(spacing: 0) {
                                Text(formatHour(hour))
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Theme.text2)
                                    .frame(width: 32, alignment: .trailing)
                                    .padding(.trailing, 4)
                                
                                HStack(spacing: 0) {
                                    ForEach(0..<7, id: \.self) { day in
                                        let cellDate = dateFor(day: day, hour: hour)
                                        gridCell(for: cellDate, day: day, hour: hour)
                                    }
                                }
                            }
                            .id(hour)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .onAppear {
                    let targetHour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(max(targetHour - 2, 0), anchor: .top)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(appearing ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appearing = true
            }
        }
        .sheet(isPresented: $showTaskEntry) {
            taskEntrySheet
        }
    }
    
    private var dateStrip: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 32)
            ForEach(0..<7, id: \.self) { index in
                let date = dateForDay(index)
                VStack(spacing: 1) {
                    Text(CalendarDayLabel.shortName(for: date, locale: vm.appLanguage.locale))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.text2)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isToday(date) ? Theme.accent : Theme.text0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 30)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.bg0)
    }
    
    private var plannerHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Theme.accent)
            Text(vm.localized("Tap a time slot to add a task"))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.bg1.opacity(0.92))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.18), lineWidth: 0.5))
        )
        .padding(.horizontal, 32)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(Theme.bg0)
    }
    
    @ViewBuilder
    private func gridCell(for date: Date, day: Int, hour: Int) -> some View {
        let isCurrentDay = isToday(dateForDay(day))
        let isCurrentHour = isCurrentDay && Calendar.current.component(.hour, from: Date()) == hour
        let minuteProgress = CGFloat(Calendar.current.component(.minute, from: Date())) / 60
        
        ZStack(alignment: .top) {
            Rectangle()
                .strokeBorder(isCurrentHour ? Theme.accent.opacity(0.48) : Theme.border.opacity(0.2), lineWidth: isCurrentHour ? 1 : 0.5)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .background(
                    isCurrentHour
                    ? Theme.accent.opacity(0.12)
                    : (isCurrentDay ? Theme.accent.opacity(0.025) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = date
                    editingTask = nil
                    newTaskTitle = ""
                    selectedHex = "#00E5FF"
                    selectedDurationMinutes = 30
                    showTaskEntry = true
                }
            
            if isCurrentHour {
                GeometryReader { proxy in
                    let y = min(max(proxy.size.height * minuteProgress, 3), proxy.size.height - 3)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(height: 1.5)
                    }
                    .shadow(color: Theme.accent.opacity(0.7), radius: 4)
                    .offset(y: y)
                }
                .frame(height: rowHeight)
                .allowsHitTesting(false)
            }
            
            let items = tasksAt(day: day, hour: hour)
            if !items.isEmpty {
                VStack(spacing: 1) {
                    ForEach(items, id: \.task.id) { item in
                        plannedTaskTile(item.task)
                            .onTapGesture {
                                editingTask = item.task
                                editingListID = item.listID
                                newTaskTitle = item.task.title
                                selectedHex = item.task.hexColor ?? "#00E5FF"
                                selectedDurationMinutes = item.task.durationMinutes ?? 30
                                selectedDate = item.task.reminderTime
                                showTaskEntry = true
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
    
    private func plannedTaskTile(_ task: SortydTask) -> some View {
        let color      = Color(hex: task.hexColor ?? "#00E5FF")
        let minutes    = CGFloat(task.durationMinutes ?? 30)
        let tileHeight = max(minutes / 60.0 * rowHeight, 14.0)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .offset(x: 2, y: 3)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.98), color.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                )
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 1),
                    alignment: .top
                )

            Text(task.title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .lineLimit(1)
                .foregroundColor(.black.opacity(0.82))
                .padding(.horizontal, 6)
                .padding(.top, 4)
        }
        .frame(height: tileHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .shadow(color: color.opacity(0.28), radius: 5, x: 0, y: 3)
        .padding(.trailing, 3)
    }
    
    private var calendarHeader: some View {
        HStack {
            Button { navigateWeek(by: -7) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.text1)
                    .frame(width: 25, height: 32)
                    .background(Circle().fill(Theme.bg1))
            }
            Spacer()
            VStack(spacing: 6) {
                Text(monthYearLabel)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)
                Text(weekDateRangeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.text2)
            }
            Spacer()
            Button { navigateWeek(by: 7) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.text1)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.bg1))
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var weekDateRangeLabel: String {
        let start = selectedWeekStart
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.locale = vm.appLanguage.locale
        return "\(df.string(from: start)) — \(df.string(from: end))"
    }
    
    private var monthYearLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        df.locale = vm.appLanguage.locale
        return df.string(from: selectedWeekStart)
    }
    
    private func navigateWeek(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedWeekStart) {
            withAnimation(.easeInOut) {
                selectedWeekStart = newDate
            }
        }
    }
    
    private var taskEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Explicit in-view top bar with Cancel so macOS & iOS users never need Escape
                HStack {
                    Button {
                        showTaskEntry = false
                    } label: {
                        Text(vm.localized("Cancel"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.text1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(vm.localized(editingTask == nil ? "Plan Your Day" : "Edit Task"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)

                    Spacer()

                    if let date = selectedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .bold))
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Theme.accent.opacity(0.12))
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 0.8))
                        )
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 14)

                // ── Task name field ──────────────────────────────────────────
                TextField(vm.localized("What are you planning?"), text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.bg1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.border.opacity(0.3), lineWidth: 0.8)
                            )
                    )
                    .padding(.bottom, 10)

                // ── Color + Timer card ───────────────────────────────────────
                HStack(spacing: 0) {
                    colorPickerSection
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.leading, 14)
                        .padding(.trailing, 10)

                    Rectangle()
                        .fill(Theme.border.opacity(0.35))
                        .frame(width: 0.8)
                        .padding(.vertical, 10)

                    timerPickerSection
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.leading, 10)
                        .padding(.trailing, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.border.opacity(0.3), lineWidth: 0.8)
                        )
                )
                .padding(.bottom, 10)

                // ── Sound hint ───────────────────────────────────────────────
                if editingTask == nil {
                    HStack(spacing: 5) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(vm.localized("Plays chime sound at reminder time"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Theme.text2.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                }

                // ── CTA + Cancel ─────────────────────────────────────────────
                HStack(spacing: 10) {
                    Button {
                        showTaskEntry = false
                    } label: {
                        Text(vm.localized("Cancel"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.bg2)
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.8))
                            )
                    }
                    .buttonStyle(.plain)

                    Button { handleTaskAction() } label: {
                        Text(vm.localized(editingTask == nil ? "Add to Calendar" : "Save Changes"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, editingTask == nil ? 0 : 8)

                if let task = editingTask, let listID = editingListID {
                    Button(role: .destructive) {
                        vm.deleteTask(task, from: listID)
                        showTaskEntry = false
                    } label: {
                        Text(vm.localized("Delete Task"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.red.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Theme.bg0)
            .navigationTitle(vm.localized(editingTask == nil ? "Plan Your Day" : "Edit Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.localized("Cancel")) { showTaskEntry = false }
                        .foregroundColor(Theme.text2)
                }
            }
        }
        #if os(macOS)
        .frame(width: 440, height: editingTask == nil ? 320 : 365)
        #endif
        .presentationDetents([.height(editingTask == nil ? 360 : 408)])
        .presentationDragIndicator(.visible)
    }
    
    private func handleTaskAction() {
        if let task = editingTask, let listID = editingListID {
            vm.updateTask(task.id, in: listID) { t in
                t.title = newTaskTitle
                t.hexColor = selectedHex
                t.durationMinutes = selectedDurationMinutes
            }
        } else if let date = selectedDate, !newTaskTitle.isEmpty {
                        vm.createTaskAtTime(title: newTaskTitle, date: date, durationMinutes: selectedDurationMinutes, soundName: "gong.wav", hexColor: selectedHex)
        }
        newTaskTitle = ""
        selectedDurationMinutes = 30
        showTaskEntry = false
        editingTask = nil
    }
    
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.localized("COLOR"))
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(Theme.text2.opacity(0.7))
                .tracking(1.2)

            HStack(spacing: 10) {
                ForEach(taskColors, id: \.self) { hex in
                    let isSelected = selectedHex == hex
                    ZStack {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                        if isSelected {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2.5)
                                .frame(width: 26, height: 26)
                            Circle()
                                .strokeBorder(Color(hex: hex), lineWidth: 1.5)
                                .frame(width: 31, height: 31)
                        }
                    }
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
                    .onTapGesture { withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { selectedHex = hex } }
                }
            }
        }
    }

    private var timerPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.localized("DURATION"))
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(Theme.text2.opacity(0.7))
                .tracking(1.2)

            HStack(spacing: 6) {
                ForEach(durationOptions, id: \.self) { minutes in
                    durationChip(minutes)
                }
            }
        }
    }

    private func durationChip(_ minutes: Int) -> some View {
        let isSelected = selectedDurationMinutes == minutes
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                selectedDurationMinutes = minutes
            }
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(isSelected ? .black : Theme.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Theme.accent : Theme.bg2.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Theme.border.opacity(0.2), lineWidth: 0.8)
                )
                .shadow(color: isSelected ? Theme.accent.opacity(0.28) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    private func dateForDay(_ dayIndex: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: selectedWeekStart) ?? selectedWeekStart
    }
    
    private func dateFor(day: Int, hour: Int) -> Date {
        let dayDate = dateForDay(day)
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: dayDate) ?? dayDate
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let df = DateFormatter()
        df.locale = vm.appLanguage.locale
        df.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return df.string(from: date).uppercased()
    }
    
    struct TaskListItem {
        let task: SortydTask
        let listID: UUID
    }
    
    private func tasksAt(day: Int, hour: Int) -> [TaskListItem] {
        let start = dateFor(day: day, hour: hour)
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        var results: [TaskListItem] = []
        guard let weeklyList = vm.weeklyList else { return [] }
        for task in weeklyList.tasks {
            if let reminder = task.reminderTime {
                if reminder >= start && reminder < end {
                    results.append(TaskListItem(task: task, listID: weeklyList.id))
                }
            }
        }
        return results
    }
}
