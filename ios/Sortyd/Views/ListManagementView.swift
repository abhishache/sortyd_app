import SwiftUI
import UserNotifications
import FirebaseAnalytics

private let kTimeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
}()

private let kOneTimeDateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
}()

// MARK: - ListManagementView

struct ListManagementView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showAdd          = false
    @State private var showStarterList  = false
    @State private var navigationPath: [UUID] = []
    @State private var editMode: EditMode = .inactive
    @State private var showArchive      = false
    @State private var confirmDeleteList: TaskList? = nil
    @State private var headerAppeared   = false
    @State private var emptyPulse       = false
    @State private var emptyRotate      = false

    private var activeLists: [TaskList] {
        let active = vm.lists.filter { !$0.isArchived && !$0.isTodo }
        guard let activeID = vm.activeListID,
              let activeList = active.first(where: { $0.id == activeID }) else {
            return active
        }
        var sorted = [activeList]
        sorted.append(contentsOf: active.filter { $0.id != activeID })
        return sorted
    }
    private var archivedLists: [TaskList] { vm.lists.filter { $0.isArchived } }
    private var isEmpty: Bool { activeLists.isEmpty && archivedLists.isEmpty }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.bg0.ignoresSafeArea()

                if ThemeManager.shared.isDark {
                    ZStack {
                        RadialGradient(
                            colors: [Color(hex: "#3ECFFF").opacity(0.055), Color.clear],
                            center: .init(x: 0.35, y: 0.0),
                            startRadius: 0, endRadius: 300
                        )
                        RadialGradient(
                            colors: [Color(hex: "#7C6FFF").opacity(0.035), Color.clear],
                            center: .init(x: 0.8, y: 0.0),
                            startRadius: 0, endRadius: 220
                        )
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                if isEmpty {
                    emptyState
                } else {
                    scrollContent
                        .environment(\.editMode, $editMode)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // FIX: keep nav bar fully invisible — no system material on scroll
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { navigationBar }
            .navigationDestination(for: UUID.self) { id in
                ListDetailView(listID: id).environmentObject(vm)
            }
            .sheet(isPresented: $showAdd) {
                AddListSheet(onSwitchToAI: { showStarterList = true }).environmentObject(vm)
            }
            .sheet(isPresented: $showStarterList) {
                StarterListSheet().environmentObject(vm)
            }
            .alert(
                "Delete List?",
                isPresented: Binding(get: { confirmDeleteList != nil }, set: { if !$0 { confirmDeleteList = nil } })
            ) {
                Button("Delete", role: .destructive) {
                    if let list = confirmDeleteList,
                       let idx = vm.lists.firstIndex(where: { $0.id == list.id }) {
                        vm.deleteList(at: IndexSet(integer: idx))
                    }
                    confirmDeleteList = nil
                }
                Button("Cancel", role: .cancel) { confirmDeleteList = nil }
            } message: {
                Text("Permanently delete \"\(confirmDeleteList?.cleanName ?? "")\" and all its tasks?")
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "list_management",
                AnalyticsParameterScreenClass: "ListManagementView"
            ])
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) { headerAppeared = true }
        }
    }

    // MARK: - Navigation Bar

    @ToolbarContentBuilder
    private var navigationBar: some ToolbarContent {

        // Principal — brand name
        ToolbarItem(placement: .principal) {
            Text("sortyd")
                .font(.system(size: 13, weight: .ultraLight))
                .tracking(5)
                .foregroundStyle(Color.white.opacity(0.9))
        }

        // Leading — gear (no container, gradient glow). Only when >0 lists.
        if !activeLists.isEmpty {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                        editMode = editMode == .active ? .inactive : .active
                    }
                } label: {
                    ZStack {
                        // Thin ring visible only when active
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.55), Theme.coral.opacity(0.35)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 34, height: 34)
                            .opacity(editMode == .active ? 1 : 0)
                            .animation(.easeInOut(duration: 0.22), value: editMode == .active)

                        Image(systemName: editMode == .active ? "checkmark" : "gearshape.fill")
                            .font(.system(size: editMode == .active ? 14 : 16, weight: .semibold))
                            .foregroundStyle(LinearGradient(
                                colors: [Theme.accent, Theme.coral],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .shadow(color: Theme.accent.opacity(0.42), radius: 6)
                            .scaleEffect(editMode == .active ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.60), value: editMode == .active)
                    }
                    .frame(width: 38, height: 38)
                    .background(Color.clear)
                }
                .buttonStyle(.plain)
            }
        }

        // Trailing — AI pill + "+" circle
        // FIX: use individual ToolbarItem instead of ToolbarItemGroup
        // to avoid the system grouping container background
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                // AI pill — filled cyan, dark text, glowing (matches empty state primary button)
                Button { showStarterList = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#060710") : .white)
                        Text(vm.appLanguage == .arabic ? "ذكاء اصطناعي" : "AI")
                            .font(.system(size: 12, weight: .black))
                            .tracking(0.6)
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#060710") : .white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Theme.accent)
                    )
                }
                .buttonStyle(.plain)
                .background(Color.clear)

                // "+" circle — unchanged, no fill change
                Button { showAdd = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .overlay(Circle().strokeBorder(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.38), Theme.coral.opacity(0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.85
                            ))
                            .frame(width: 30, height: 30)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [Theme.accent, Theme.coral],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    }
                }
                .buttonStyle(.plain)
                .background(Color.clear)
            }
            .background(Color.clear)
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        List {
            sectionHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

            ForEach(activeLists) { list in
                ObsidianListCard(
                    list: list,
                    isActive: vm.activeListID == list.id,
                    onTap: { navigationPath.append(list.id) },
                    onArchive: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { vm.archiveList(list) }
                    },
                    onDelete: { confirmDeleteList = list }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                .deleteDisabled(editMode == .inactive)
            }
            .onMove { source, destination in
                moveActiveLists(from: source, to: destination)
            }
            .onDelete { offsets in
                for idx in offsets.sorted().reversed() {
                    confirmDeleteList = activeLists[idx]
                }
            }

            if !archivedLists.isEmpty { archivedSection }

            Color.clear.frame(height: 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listRowSpacing(0)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Lists")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .opacity(headerAppeared ? 1 : 0)
                        .offset(y: headerAppeared ? 0 : 12)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05), value: headerAppeared)

                    Text("Active list would be default across widgets and the analysis.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.text2)
                        .opacity(headerAppeared ? 0.8 : 0)
                        .padding(.top, -2)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1), value: headerAppeared)

                    if !activeLists.isEmpty {
                        let total   = activeLists.reduce(0) { $0 + $1.tasks.count }
                        let done    = activeLists.reduce(0) { $0 + $1.tasks.filter { $0.isCompleted }.count }
                        let pending = total - done
                        HStack(spacing: 6) {
                            if done > 0    { statPill(value: done,    label: vm.appLanguage == .arabic ? "تم" : (vm.appLanguage == .spanish ? "hecho" : "done"),  color: Theme.success) }
                            if pending > 0 { statPill(value: pending, label: vm.appLanguage == .arabic ? "متبقي" : (vm.appLanguage == .spanish ? "restantes" : "left"),  color: Theme.accent)  }
                            if total == 0  { statPill(value: 0,       label: vm.appLanguage == .arabic ? "لا مهام" : (vm.appLanguage == .spanish ? "sin tareas" : "no tasks"), color: Theme.text2) }
                        }
                        .opacity(headerAppeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.14), value: headerAppeared)
                    }
                }

                Spacer()

                if !activeLists.isEmpty {
                    listCountBadge
                        .opacity(headerAppeared ? 1 : 0)
                        .scaleEffect(headerAppeared ? 1 : 0.7)
                        .animation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.18), value: headerAppeared)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 14)

            Rectangle()
                .fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.18), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .opacity(headerAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.28), value: headerAppeared)
        }
    }

    private func statPill(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(value)").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(color.opacity(0.70))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().strokeBorder(color.opacity(0.20), lineWidth: 0.75))
        )
    }

    private var listCountBadge: some View {
        VStack(spacing: 2) {
            Text("\(activeLists.count)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Theme.accent, Theme.coral],
                    startPoint: .top, endPoint: .bottom
                ))
                .contentTransition(.numericText())
            Text(activeLists.count == 1 ? String(localized: "list") : String(localized: "lists"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(Theme.text2)
        }
        .frame(width: 52)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bg2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.75))
        )
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showArchive) {
                ForEach(archivedLists) { list in
                    ArchivedCard(list: list)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { vm.restoreList(list) }
                            } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                                .tint(Theme.accent)
                            Button(role: .destructive) { vm.permanentlyDeleteList(list) }
                                label: { Label("Delete", systemImage: "trash") }
                        }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox.fill").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.text2)
                    Text("ARCHIVED").font(.system(size: 10, weight: .black)).tracking(2.5).foregroundColor(Theme.text2)
                    Spacer()
                    Text("\(archivedLists.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5)))
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
            }
            .tint(Theme.text2)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Empty State
    // FIX: Animations triggered locally so they always run when empty state is visible

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated ring cluster with floating sparkles
            ZStack {
                ForEach(Array(zip([260, 200, 148, 104].indices, [260, 200, 148, 104])), id: \.0) { i, size in
                    let opacities: [Double] = [0.03, 0.055, 0.10, 0.16]
                    let delays: [Double]    = [0, 0.18, 0.36, 0.52]
                    Circle()
                        .stroke(Theme.accent.opacity(emptyPulse ? opacities[i] * 0.5 : opacities[i]), lineWidth: 1)
                        .frame(
                            width:  emptyPulse ? CGFloat(size) + 18 : CGFloat(size),
                            height: emptyPulse ? CGFloat(size) + 18 : CGFloat(size)
                        )
                        .animation(
                            .easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(delays[i]),
                            value: emptyPulse
                        )
                }

                Circle()
                    .trim(from: 0.0, to: 0.35)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent.opacity(0.30), Color.clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: 148, height: 148)
                    .rotationEffect(.degrees(emptyRotate ? 360 : 0))
                    .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: emptyRotate)

                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Theme.accent.opacity(emptyPulse ? 0.22 : 0.10),
                            Theme.coral.opacity(0.06),
                            Color.clear
                        ],
                        center: .center, startRadius: 0, endRadius: 44
                    ))
                    .frame(width: 88, height: 88)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: emptyPulse)

                Circle()
                    .strokeBorder(Theme.accent.opacity(0.28), lineWidth: 1)
                    .frame(width: 80, height: 80)

                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [Theme.accent, Theme.coral],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .scaleEffect(emptyPulse ? 1.07 : 1.0)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: emptyPulse)

                ForEach(0..<5, id: \.self) { i in
                    let angles: [Double]  = [30, 95, 160, 225, 310]
                    let radii:  [CGFloat] = [88, 82, 94, 80, 90]
                    let sizes:  [CGFloat] = [4, 3, 5, 3, 4]
                    let angle = angles[i] * .pi / 180
                    Circle()
                        .fill(i % 2 == 0 ? Theme.accent : Theme.coral)
                        .frame(width: sizes[i], height: sizes[i])
                        .offset(
                            x: cos(angle) * radii[i],
                            y: sin(angle) * radii[i]
                        )
                        .opacity(emptyPulse ? 0.80 : 0.25)
                        .scaleEffect(emptyPulse ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 2.6).repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.22),
                            value: emptyPulse
                        )
                }
            }
            .frame(width: 280, height: 280)
            .padding(.bottom, 24)

            VStack(spacing: 8) {
                Text(vm.appLanguage == .arabic ? "لوحتك فارغة" : (vm.appLanguage == .spanish ? "Tu lienzo está vacío" : "Your canvas is empty"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text0)
                    .multilineTextAlignment(.center)
                Text(vm.appLanguage == .arabic ? "دع الذكاء الاصطناعي يبني قائمتك الأولى،\nأو أنشئ واحدة بنفسك." : (vm.appLanguage == .spanish ? "Deja que la IA cree tu primera lista,\no crea una tú mismo." : "Let AI build your first list,\nor create one yourself."))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.bottom, 32)

            // REDESIGNED BUTTONS: AI primary (full width, glowing), Manual secondary (ghost pill below)
            VStack(spacing: 12) {
                // Primary — AI (full width, prominent glow)
                Button { showStarterList = true } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#060710") : .white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vm.appLanguage == .arabic ? "أنشئ بواسطة الذكاء الاصطناعي" : (vm.appLanguage == .spanish ? "Generar con IA" : "Generate with AI"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#060710") : .white)
                            Text(vm.appLanguage == .arabic ? "صف هدفك، والذكاء الاصطناعي يبنيه" : (vm.appLanguage == .spanish ? "Describe tu objetivo, la IA lo crea" : "Describe your goal, AI builds it"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor((ThemeManager.shared.isDark ? Color(hex: "#060710") : Color.white).opacity(0.60))
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .flipsForRightToLeftLayoutDirection(true)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor((ThemeManager.shared.isDark ? Color(hex: "#060710") : Color.white).opacity(0.70))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.55), radius: 24, x: 0, y: 8)
                            .shadow(color: Theme.accent.opacity(0.25), radius: 48, x: 0, y: 16)
                    )
                }
                .buttonStyle(ListScaleStyle())

                // Divider row
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                    Text("or")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.text2)
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 8)

                // Secondary — Manual (ghost, smaller, understated)
                Button { showAdd = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text1)
                        Text(vm.appLanguage == .arabic ? "أنشئ يدويًا" : (vm.appLanguage == .spanish ? "Crear manualmente" : "Create manually"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.text1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.bg2.opacity(0.60))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 0.75)
                            )
                    )
                }
                .buttonStyle(ListScaleStyle())
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        // FIX: restart animations every time empty state appears
        // The NavigationStack .onAppear only fires once at launch — animations die if
        // the user adds a list then deletes it. This fires whenever emptyState becomes visible.
        .onAppear {
            emptyPulse  = false
            emptyRotate = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { emptyPulse = true }
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { emptyRotate = true }
            }
        }
    }

    // MARK: - Helpers

    private func moveActiveLists(from source: IndexSet, to destination: Int) {
        let activeIDs   = activeLists.map(\.id)
        let fullIndices = source.compactMap { idx -> Int? in
            vm.lists.firstIndex(where: { $0.id == activeIDs[idx] })
        }
        let clampedDest = min(destination, activeIDs.count - 1)
        let destID      = activeIDs[clampedDest]
        var fullDest    = vm.lists.firstIndex(where: { $0.id == destID }) ?? 0
        if destination >= activeLists.count { fullDest += 1 }
        vm.moveList(from: IndexSet(fullIndices), to: fullDest)
    }
}

// MARK: - ObsidianListCard

private struct ObsidianListCard: View {
    let list: TaskList
    let isActive: Bool
    let onTap: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var vm: AppViewModel
    @State private var progressAppeared = false
    @State private var showRename = false

    private var completedCount: Int { list.tasks.filter(\.isCompleted).count }
    private var totalCount: Int      { list.tasks.count }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.bg1)

                if isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.accent.opacity(0.05), Theme.coral.opacity(0.02), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isActive
                            ? LinearGradient(
                                colors: [Theme.accent.opacity(0.45), Theme.coral.opacity(0.20)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Theme.border, Theme.border],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isActive ? 1 : 0.5
                    )

                if isActive {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Theme.accent, Theme.coral.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 3.5)
                            .padding(.vertical, 14)
                            .shadow(color: Theme.accent.opacity(0.80), radius: 10, x: 2, y: 0)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.4, anchor: .leading)))
                }

                HStack(spacing: 12) {
                    if isActive { Color.clear.frame(width: 6) }

                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(isActive ? Theme.accent.opacity(0.10) : Theme.bg2)
                            .frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    isActive ? Theme.accent.opacity(0.28) : Theme.border,
                                    lineWidth: isActive ? 1 : 0.5
                                ))
                        Text(list.emoji).font(.system(size: 22))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(list.cleanName)
                                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text0)
                                .lineLimit(1)
                            if isActive {
                                Text(vm.appLanguage == .arabic ? "نشط" : (vm.appLanguage == .spanish ? "ACTIVO" : "ACTIVE"))
                                    .font(.system(size: 7, weight: .black))
                                    .tracking(1.5)
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 5).padding(.vertical, 2.5)
                                    .background(
                                        Capsule()
                                            .fill(Theme.accent.opacity(0.10))
                                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.28), lineWidth: 0.75))
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        taskDotStrip

                        Group {
                            if totalCount == 0 {
                                Text(vm.appLanguage == .arabic ? "لا توجد مهام بعد" : (vm.appLanguage == .spanish ? "Sin tareas aún" : "No tasks yet")).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.text2)
                            } else if completedCount == totalCount {
                                Text(vm.appLanguage == .arabic ? "كل الـ \(totalCount) تمت 🎉" : (vm.appLanguage == .spanish ? "¡Las \(totalCount) completadas! 🎉" : "All \(totalCount) done 🎉")).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.success)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Text(vm.appLanguage == .arabic ? "\(completedCount) من \(totalCount) تمت" : (vm.appLanguage == .spanish ? "\(completedCount) de \(totalCount) hechas" : "\(completedCount) of \(totalCount) done")).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.text2)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: completedCount)
                    }

                    Spacer(minLength: 0)

                    Menu {
                        Button { showRename = true } label: { Label("Rename", systemImage: "pencil") }
                            .accessibilityLabel("Rename \(list.name)")
                        Button(action: onArchive) { Label("Archive", systemImage: "archivebox") }
                            .accessibilityLabel("Archive \(list.name)")
                        Button(role: .destructive, action: onDelete) { Label("Delete List", systemImage: "trash") }
                            .accessibilityLabel("Delete \(list.name)")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.text2.opacity(0.50))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.bg2).overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5)))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture())
                }
                .padding(.horizontal, 12).padding(.vertical, 13)
            }
        }
        .buttonStyle(CardPressStyle())
        .shadow(
            color: isActive ? Theme.accent.opacity(0.18) : .black.opacity(0.36),
            radius: isActive ? 20 : 10, x: 0, y: isActive ? 7 : 4
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { progressAppeared = true }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onArchive) { Label("Archive", systemImage: "archivebox") }
                .tint(Color(hex: "#6B7280"))
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                .tint(Color(hex: "#EF4444"))
        }
        .contextMenu {
            Button { showRename = true } label: { Label("Rename", systemImage: "pencil") }
            Button(action: onArchive) { Label("Archive", systemImage: "archivebox") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .sheet(isPresented: $showRename) {
            RenameListSheet(list: list) { newName, newEmoji in
                vm.renameList(list, name: newName, emoji: newEmoji)
            }
        }
    }

    @ViewBuilder
    private var taskDotStrip: some View {
        if totalCount == 0 {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Theme.bg3).frame(width: 14, height: 4)
                }
            }
        } else {
            let maxDots = min(totalCount, 10)
            let doneScaled = totalCount > 10 ? Int((Double(completedCount) / Double(totalCount)) * 10.0) : completedCount
            HStack(spacing: 3) {
                ForEach(0..<maxDots, id: \.self) { i in
                    let filled = i < doneScaled
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(filled ? (isActive ? Theme.accent : Theme.accent.opacity(0.65)) : Theme.bg3)
                        .frame(width: filled ? 16 : 10, height: 4)
                        .shadow(color: filled ? Theme.accent.opacity(isActive ? 0.55 : 0.25) : .clear, radius: 3)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: doneScaled)
                }
                if totalCount > 10 {
                    Text("+\(totalCount - 10)").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.text2)
                }
            }
        }
    }
}

// MARK: - ArchivedCard

private struct ArchivedCard: View {
    let list: TaskList

    var body: some View {
        HStack(spacing: 12) {
            Text(list.emoji)
                .font(.system(size: 17)).opacity(0.45)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.bg2)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5)))

            VStack(alignment: .leading, spacing: 2) {
                Text(list.cleanName).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text1).lineLimit(1)
                Text("\(list.tasks.count) task\(list.tasks.count == 1 ? "" : "s")").font(.system(size: 11)).foregroundColor(Theme.text2)
            }
            Spacer()
            Image(systemName: "archivebox").font(.system(size: 11, weight: .medium)).foregroundColor(Theme.text2.opacity(0.35))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bg1.opacity(0.60))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
        )
    }
}

// MARK: - Button Styles

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private struct ListScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// ══════════════════════════════════════════════
// MARK: ListDetailView
// ══════════════════════════════════════════════

struct ListDetailView: View {
    let listID: UUID
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.undoManager) var undoManager

    @State private var showAdd      = false
    @State private var showSmartAdd = false
    @State private var editing: SortydTask? = nil

    private var list: TaskList? { vm.lists.first(where: { $0.id == listID }) }

    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            if let list {
                if list.tasks.isEmpty { emptyState } else { taskList(list: list) }
            }
        }
        .navigationTitle(list.map { "\($0.emoji) \($0.cleanName)" } ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.bg0, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(undoManager?.canUndo == true ? Theme.accent : Theme.text2.opacity(0.35))
                }
                .disabled(undoManager?.canUndo != true)

                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(undoManager?.canRedo == true ? Theme.accent : Theme.text2.opacity(0.35))
                }
                .disabled(undoManager?.canRedo != true)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let list, !list.tasks.isEmpty {
                    EditButton().foregroundColor(Theme.accent).fontWeight(.semibold)
                }
                Button { showSmartAdd = true } label: {
                    ZStack {
                        Circle().fill(Theme.coral.opacity(0.10)).frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Theme.coral.opacity(0.20), lineWidth: 0.75))
                        Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.coral)
                    }
                }
                Button { showAdd = true } label: {
                    ZStack {
                        Circle().fill(Theme.accent).frame(width: 30, height: 30)
                        Image(systemName: "plus").font(.system(size: 12, weight: .black))
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                    }
                    .shadow(color: Theme.accent.opacity(0.42), radius: 10, x: 0, y: 3)
                }
            }
        }
        .sheet(isPresented: $showAdd)      { AddTaskSheet(listID: listID).environmentObject(vm) }
        .sheet(isPresented: $showSmartAdd) { SmartAddTaskSheet(listID: listID).environmentObject(vm) }
        .sheet(item: $editing)             { task in EditTaskSheet(task: task, listID: listID).environmentObject(vm) }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.accent.opacity(0.06)).frame(width: 90, height: 90)
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(0.12), lineWidth: 1))
                Circle().fill(Theme.accent.opacity(0.10)).frame(width: 60, height: 60)
                Text("✅").font(.system(size: 24))
            }
            VStack(spacing: 6) {
                Text("No tasks yet").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(Theme.text0)
                Text("Add your first task to get started.").font(.system(size: 13.5)).foregroundColor(Theme.text1)
            }
            HStack(spacing: 10) {
                Button { showSmartAdd = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .black))
                        Text("Smart Add").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.accent).shadow(color: Theme.accent.opacity(0.40), radius: 12, x: 0, y: 5))
                }
                .buttonStyle(ListScaleStyle())
                Button { showAdd = true } label: {
                    Text("Manual").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text1)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5)))
                }
                .buttonStyle(ListScaleStyle())
            }
            Spacer()
        }
    }

    private func taskList(list: TaskList) -> some View {
        List {
            ForEach(list.tasks) { task in
                TaskDetailRow(task: task, onDelete: { vm.deleteTask(task, from: listID, undoManager: undoManager) })
                    .contentShape(Rectangle())
                    .onTapGesture { editing = task }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                            .fill(Theme.bg1)
                            .overlay(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 0.5))
                    )
                    .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for idx in offsets.sorted().reversed() { vm.deleteTask(list.tasks[idx], from: listID, undoManager: undoManager) }
            }
            .onMove { vm.moveTasks(in: listID, from: $0, to: $1, undoManager: undoManager) }
        }
        .listRowSpacing(8)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - TaskDetailRow

private struct TaskDetailRow: View {
    let task: SortydTask
    var onDelete: (() -> Void)? = nil
    @StateObject private var hk = HealthKitManager.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text0).lineLimit(1)
                    if task.isHealthTask, let htStr = task.healthType, let ht = HealthTaskType(rawValue: htStr) {
                        Image(systemName: ht.icon).font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Color(hex: ht.accentColor))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: ht.accentColor).opacity(0.12)))
                    }
                }
                HStack(spacing: 8) {
                    if let t = task.reminderTime {
                        HStack(spacing: 3) {
                            Image(systemName: "bell.fill").font(.system(size: 7))
                                .foregroundColor(Color(hex: "#00E5FF"))
                            Text(task.reminderIsOneTime ? kOneTimeDateFormatter.string(from: t) : kTimeFormatter.string(from: t))
                                .font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "#00E5FF"))
                        }
                    }
                    
                    if task.isHealthTask, let target = task.healthTarget,
                              let htStr = task.healthType, let ht = HealthTaskType(rawValue: htStr) {
                        Text("\(ht == .distance ? String(format: "%.1f", hk.currentValue(for: ht)) : String(format: "%.0f", hk.currentValue(for: ht))) / \(Int(target)) \(ht.label.lowercased())")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: ht.accentColor))
                    } else if task.reminderTime == nil {
                        Text("No reminder").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.text2)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: task.reminderTime)
            }
            
            Spacer()
            
            Image(systemName: "pencil")
                .font(.system(size: 14))
                .foregroundColor(Theme.text2.opacity(0.4)) // Lighter color
            
            if let del = onDelete {
                Button(action: del) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.text2.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.bg3.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }
}

// ══════════════════════════════════════════════
// MARK: AddListSheet
// ══════════════════════════════════════════════

struct AddListSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    var onSwitchToAI: (() -> Void)? = nil

    @State private var name  = ""
    @State private var emoji = "📋"

    private let emojis = ["📋","💪","🧠","🎯","📚","💼","🌿","🎨","🏃","🍎",
                          "💤","🧘","✈️","🎵","💡","🔥","⚡","🏋️","📖","🎤",
                          "🧪","🌍","💰","🧹","🛒","🧴","🐾","☕","🎮","🏠",
                          "🤝","📸","🚴","🥗","🧃","🛌","📝","🚀","🌙","⭐",
                          "🤰​","🏄‍♂️​"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.s20) {
                        sheetLabel("LIST NAME")
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.bg2)
                                    .frame(width: 44, height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Theme.border, lineWidth: 0.5))
                                Text(emoji).font(.system(size: 20))
                            }
                            
                            TextField("e.g. Morning Routine", text: $name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.text0)
                        }
                        .padding(Theme.s12)
                        .background(fieldBG(Theme.r12))
                            // FIX: user must tap to open keyboard — no auto-focus

                        sheetLabel("ICON")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(emojis, id: \.self) { e in
                                Button { emoji = e } label: {
                                    Text(e).font(.system(size: 22))
                                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(emoji == e ? Theme.accent.opacity(0.14) : Theme.bg2)
                                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(emoji == e ? Theme.accent.opacity(0.50) : Theme.border, lineWidth: 0.5))
                                        )
                                        .scaleEffect(emoji == e ? 1.08 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: emoji == e)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.s20).padding(.top, Theme.s20).padding(.bottom, 100)
                }
            }
            .background(Theme.bg0)
            .navigationTitle("New List").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.text1)
                }
                if let switchToAI = onSwitchToAI {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { switchToAI() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                                Text("AI").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    vm.addList(name: n, emoji: emoji); dismiss()
                } label: {
                    Text("Add List")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                            .fill(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.text2 : Theme.accent))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(ListScaleStyle())
                .padding(.horizontal, Theme.s20).padding(.vertical, 12)
                .background(Theme.bg0)
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.r32).presentationBackground(Theme.bg0)
    }
}

// ══════════════════════════════════════════════
// MARK: RenameListSheet
// ══════════════════════════════════════════════

struct RenameListSheet: View {
    let list: TaskList
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var emoji: String

    private let emojis = ["📋","💪","🧠","🎯","📚","💼","🌿","🎨","🏃","🍎",
                          "💤","🧘","✈️","🎵","💡","🔥","⚡","🏋️","📖","🎤",
                          "🧪","🌍","💰","🧹","🛒","🧴","🐾","☕","🎮","🏠",
                          "🤝","📸","🚴","🥗","🧃","🛌","📝","🚀","🌙","⭐",
                          "🤰​","🏄‍♂️​"]

    init(list: TaskList, onSave: @escaping (String, String) -> Void) {
        self.list   = list
        self.onSave = onSave
        _name  = State(initialValue: list.name)
        _emoji = State(initialValue: list.emoji)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.s20) {
                        sheetLabel("LIST NAME")
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.bg2)
                                    .frame(width: 44, height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Theme.border, lineWidth: 0.5))
                                Text(emoji).font(.system(size: 20))
                            }
                            
                            TextField("List name", text: $name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.text0)
                        }
                        .padding(Theme.s12)
                        .background(fieldBG(Theme.r12))

                        sheetLabel("ICON")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(emojis, id: \.self) { e in
                                Button { emoji = e } label: {
                                    Text(e).font(.system(size: 22))
                                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(emoji == e ? Theme.accent.opacity(0.14) : Theme.bg2)
                                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(emoji == e ? Theme.accent.opacity(0.50) : Theme.border, lineWidth: 0.5))
                                        )
                                        .scaleEffect(emoji == e ? 1.08 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: emoji == e)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.s20).padding(.top, Theme.s20).padding(.bottom, 100)
                }
            }
            .background(Theme.bg0)
            .navigationTitle("Rename List").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.text1)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    onSave(n, emoji); dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                            .fill(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.text2 : Theme.accent))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(ListScaleStyle())
                .padding(.horizontal, Theme.s20).padding(.vertical, 12)
                .background(Theme.bg0)
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.r32).presentationBackground(Theme.bg0)
    }
}

// ══════════════════════════════════════════════
// MARK: AddTaskSheet
// ══════════════════════════════════════════════

struct AddTaskSheet: View {
    let listID: UUID
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var hk = HealthKitManager.shared

    @State private var title               = ""
    @State private var reminderTime: Date?     = nil
    @State private var reminderIsOneTime: Bool = false
    @State private var showTimePicker          = false
    @State private var showDeniedAlert         = false
    @State private var isSaving                = false
    @State private var detectedHealthType: HealthTaskType = .none
    @State private var healthTargetText    = ""
    @State private var showHealthPermSheet = false
    @State private var lastDetectedType: HealthTaskType = .none
    @State private var conflictHealthType: HealthTaskType? = nil
    @State private var showConflictToast   = false
    @State private var manualTypeSet       = false
    @State private var reminderConflict: AppViewModel.ReminderConflictInfo? = nil
    @State private var showReminderConflictToast = false

    private var healthTarget: Double? {
        guard detectedHealthType != .none, let v = Double(healthTargetText), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.s16) {
                        sheetLabel("TASK NAME")
                        HStack(spacing: 10) {
                            TextField("What do you need to do?", text: $title)
                                .font(.system(size: 16, weight: .medium)).foregroundColor(Theme.text0)
                                .autocorrectionDisabled()
                                .onChange(of: title) { _, v in detectHealth(from: v) }
                            Button { showTimePicker = true } label: {
                                ZStack {
                                    Circle()
                                        .fill(reminderTime != nil ? Theme.accent.opacity(0.12) : Theme.bg3)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: reminderTime != nil ? Theme.accent.opacity(0.30) : .clear, radius: 8, x: 0, y: 2)
                                    Image(systemName: reminderTime != nil ? "clock.fill" : "clock")
                                        .font(.system(size: 16))
                                        .foregroundColor(reminderTime != nil ? Theme.accent : Theme.text2)
                                }
                                .animation(.easeInOut(duration: 0.15), value: reminderTime != nil)
                            }.buttonStyle(.plain)
                        }
                        .padding(Theme.s16).background(fieldBG(Theme.r12))

                        VStack(alignment: .leading, spacing: 10) {
                            sheetLabel("TASK TYPE")
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    typePill(type: .none, label: vm.localized("Regular"))
                                    typePill(type: .steps, label: vm.localized("Steps"))
                                }
                                HStack(spacing: 8) {
                                    typePill(type: .calories, label: vm.localized("Calories"))
                                    typePill(type: .distance, label: vm.localized("Distance"))
                                }
                            }
                            Text(vm.localized("Only one task from step count, calorie count or distance measure is allowed."))
                                .font(.system(size: 9, weight: .bold)) // Standardized to 9pt bold
                                .foregroundColor(Theme.text2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }

                        if let t = reminderTime {
                            ReminderBanner(time: t, isOneTime: reminderIsOneTime) { reminderTime = nil; reminderIsOneTime = false }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        if detectedHealthType != .none {
                            HealthTargetBanner(taskType: detectedHealthType, targetText: $healthTargetText,
                                               onRequestPermission: { showHealthPermSheet = true })
                            .sheet(isPresented: $showHealthPermSheet) {
                                HealthPermissionSheet(taskType: detectedHealthType, onGrant: {}, onSkip: {})
                            }
                        }
                        if showConflictToast, let ct = conflictHealthType {
                            HealthConflictToast(type: ct, isVisible: $showConflictToast)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        if showReminderConflictToast, let rc = reminderConflict {
                            ReminderConflictToast(conflict: rc, isVisible: $showReminderConflictToast)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 16)
                    }
                    .padding(Theme.s20)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: reminderTime != nil)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: detectedHealthType)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showReminderConflictToast)
                }
            }
            .navigationTitle("New Task").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(Theme.text1) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: confirmAdd) {
                        Text("Add").font(.system(size: 14, weight: .bold))
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(title.isEmpty ? Theme.text2 : Theme.accent)
                                .shadow(color: title.isEmpty ? .clear : Theme.accent.opacity(0.35), radius: 8, x: 0, y: 2))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.r32).presentationBackground(Theme.bg0)
        .sheet(isPresented: $showTimePicker) {
            ReminderPickerSheet(selectedTime: reminderDefault, isOneTime: reminderIsOneTime) { time, oneTime in
                reminderTime = time; reminderIsOneTime = oneTime
            }
        }
        .sheet(isPresented: $showHealthPermSheet) {
            HealthPermissionSheet(taskType: detectedHealthType, onGrant: { hk.fetchToday() }, onSkip: {})
                .presentationDetents([.large]).presentationCornerRadius(Theme.r32).presentationBackground(Theme.bg0)
        }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enable notifications for Sortyd in Settings to receive task reminders.") }
    }

    private func detectHealth(from text: String) {
        if manualTypeSet { return }
        let detected = HealthTaskType.detect(from: text)
        withAnimation { detectedHealthType = detected }
        if detected != .none && detected != lastDetectedType && !hk.isAuthorized {
            lastDetectedType = detected
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if detectedHealthType != .none { showHealthPermSheet = true } }
        }
        if detected == .none { lastDetectedType = .none }
    }

    @ViewBuilder
    private func typePill(type: HealthTaskType, label: String) -> some View {
        let isSelected = detectedHealthType == type
        let isBlocked  = type != .none && vm.duplicateHealthType(type.rawValue, in: listID) != nil
        let accent: Color = {
            switch type {
            case .none:     return Color(hex: "#FFC107")
            case .steps:    return Color(hex: "#4FC3F7")
            case .calories: return Color(hex: "#FF7043")
            case .distance: return Color(hex: "#2E7D32")
            }
        }()

        Button {
            if isBlocked {
                conflictHealthType = type
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showConflictToast = true
                }
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                detectedHealthType = type
                manualTypeSet = true
            }
        } label: {
            HStack(spacing: 6) {
                if type != .none {
                    Image(systemName: type.icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : (isBlocked ? Theme.text2.opacity(0.25) : Theme.text1))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? accent : (isBlocked ? Theme.bg2.opacity(0.3) : Theme.bg2))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? Color.white.opacity(0.2) : (isBlocked ? Color.clear : Theme.border), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBlocked || isSaving)
        .opacity(isBlocked ? 0.5 : 1.0)
    }

    private var reminderDefault: Date {
        if let e = reminderTime { return e }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private func confirmAdd() {
        let t = title.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        let htString = detectedHealthType != .none ? detectedHealthType.rawValue : nil

        // Block if a health task of the same type already exists in this list
        if let conflict = vm.duplicateHealthType(htString, in: listID) {
            conflictHealthType = conflict
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showConflictToast = true
            }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
            return
        }

        if let time = reminderTime {
            let cal = Calendar.current
            if let conflict = vm.findReminderConflict(hour: cal.component(.hour, from: time),
                                                       minute: cal.component(.minute, from: time),
                                                       in: listID) {
                reminderConflict = conflict
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showReminderConflictToast = true }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            isSaving = true
            Task {
                let granted = await NotificationManager.shared.requestPermissionIfNeeded()
                await MainActor.run {
                    isSaving = false
                    vm.addTask(to: listID, title: t, reminderTime: granted ? time : nil,
                               reminderIsOneTime: reminderIsOneTime, healthType: htString, healthTarget: healthTarget)
                    dismiss()
                    if !granted { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showDeniedAlert = true } }
                }
            }
        } else {
            vm.addTask(to: listID, title: t, reminderTime: nil, healthType: htString, healthTarget: healthTarget)
            dismiss()
        }
    }
}

// ══════════════════════════════════════════════
// MARK: EditTaskSheet
// ══════════════════════════════════════════════

struct EditTaskSheet: View {
    let task: SortydTask
    let listID: UUID
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var reminderTime: Date?
    @State private var reminderIsOneTime: Bool
    @State private var healthTargetText: String
    @State private var showTimePicker  = false
    @State private var showDeniedAlert = false
    @State private var isSaving        = false
    @State private var reminderConflict: AppViewModel.ReminderConflictInfo? = nil
    @State private var showReminderConflictToast = false

    init(task: SortydTask, listID: UUID) {
        self.task = task; self.listID = listID
        _title             = State(initialValue: task.title)
        _reminderTime      = State(initialValue: task.reminderTime)
        _reminderIsOneTime = State(initialValue: task.reminderIsOneTime)
        _healthTargetText  = State(initialValue: task.healthTarget.map { String(Int($0)) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Theme.s16) {
                    sheetLabel("TASK NAME")
                    HStack(spacing: 10) {
                        TextField("Task name", text: $title)
                            .font(.system(size: 16, weight: .medium)).foregroundColor(Theme.text0).autocorrectionDisabled()
                        Button { showTimePicker = true } label: {
                            ZStack {
                                Circle()
                                    .fill(reminderTime != nil ? Theme.accent.opacity(0.12) : Theme.bg3)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: reminderTime != nil ? Theme.accent.opacity(0.28) : .clear, radius: 7, x: 0, y: 2)
                                Image(systemName: reminderTime != nil ? "clock.fill" : "clock")
                                    .font(.system(size: 16)).foregroundColor(reminderTime != nil ? Theme.accent : Theme.text2)
                            }
                            .animation(.easeInOut(duration: 0.15), value: reminderTime != nil)
                        }.buttonStyle(.plain)
                    }
                    .padding(Theme.s16).background(fieldBG(Theme.r12))

                    if let t = reminderTime {
                        ReminderBanner(time: t, isOneTime: reminderIsOneTime) { reminderTime = nil; reminderIsOneTime = false }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showReminderConflictToast, let rc = reminderConflict {
                        ReminderConflictToast(conflict: rc, isVisible: $showReminderConflictToast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if task.isHealthTask, let htStr = task.healthType, let ht = HealthTaskType(rawValue: htStr) {
                        VStack(alignment: .leading, spacing: 6) {
                            sheetLabel("HEALTH GOAL")
                            HStack(spacing: 8) {
                                Image(systemName: ht.icon).font(.system(size: 13)).foregroundColor(Color(hex: ht.accentColor))
                                TextField(ht.placeholder, text: $healthTargetText)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text0)
                                Text(ht.label.lowercased())
                                    .font(.system(size: 13)).foregroundColor(Theme.text2)
                            }
                            .padding(11)
                            .background(RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                                .fill(Color(hex: ht.accentColor).opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                                    .strokeBorder(Color(hex: ht.accentColor).opacity(0.25), lineWidth: 0.5)))
                        }
                    }
                    Spacer()
                }
                .padding(Theme.s20)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: reminderTime != nil)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showReminderConflictToast)
            }
            .navigationTitle("Edit Task").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(Theme.text1) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: confirmSave) {
                        Text("Save").font(.system(size: 14, weight: .bold))
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Theme.accent).shadow(color: Theme.accent.opacity(0.35), radius: 8, x: 0, y: 2))
                    }.disabled(isSaving)
                }
            }
        }
        .presentationDetents(showReminderConflictToast ? [.medium] : [.height(task.isHealthTask ? 350 : 300)]).presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.r32).presentationBackground(Theme.bg0)
        .sheet(isPresented: $showTimePicker) {
            ReminderPickerSheet(selectedTime: reminderDefault, isOneTime: reminderIsOneTime) { time, oneTime in
                reminderTime = time; reminderIsOneTime = oneTime
            }
        }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enable notifications for Sortyd in Settings to receive task reminders.") }
    }

    private var reminderDefault: Date {
        if let e = reminderTime { return e }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private func confirmSave() {
        let t = title.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        vm.updateTaskTitle(task, in: listID, newTitle: t)
        if task.isHealthTask {
            let newTarget = Double(healthTargetText.trimmingCharacters(in: .whitespaces))
            vm.updateHealthTarget(task, in: listID, target: newTarget)
        }
        if let time = reminderTime {
            let cal = Calendar.current
            if let conflict = vm.findReminderConflict(hour: cal.component(.hour, from: time),
                                                       minute: cal.component(.minute, from: time),
                                                       in: listID, excludingTaskID: task.id) {
                reminderConflict = conflict
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showReminderConflictToast = true }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            isSaving = true
            Task {
                let granted = await vm.setTaskReminder(task, in: listID, time: time, isOneTime: reminderIsOneTime)
                await MainActor.run {
                    isSaving = false; dismiss()
                    if !granted { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showDeniedAlert = true } }
                }
            }
        } else {
            if task.reminderTime != nil { vm.clearTaskReminder(task, in: listID) }
            dismiss()
        }
    }
}

// ══════════════════════════════════════════════
// MARK: ReminderPickerSheet
// ══════════════════════════════════════════════

struct ReminderPickerSheet: View {
    let selectedTime: Date
    let isOneTime: Bool
    let onConfirm: (Date, Bool) -> Void
    @Environment(\.dismiss) var dismiss

    private enum ReminderMode { case daily, oneTime }
    @State private var mode: ReminderMode
    @State private var dailyTime: Date
    @State private var oneTimeDate: Date

    init(selectedTime: Date, isOneTime: Bool, onConfirm: @escaping (Date, Bool) -> Void) {
        self.selectedTime = selectedTime
        self.isOneTime    = isOneTime
        self.onConfirm    = onConfirm
        _mode      = State(initialValue: isOneTime ? .oneTime : .daily)
        _dailyTime = State(initialValue: selectedTime)
        let tomorrow9: Date = {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.day = (c.day ?? 0) + 1; c.hour = 9; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        }()
        _oneTimeDate = State(initialValue: isOneTime && selectedTime > Date() ? selectedTime : tomorrow9)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab("Daily", active: mode == .daily) { withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { mode = .daily } }
                        modeTab("One-time", active: mode == .oneTime) { withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { mode = .oneTime } }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.bg2)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 0.5)))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                    if mode == .daily {
                        dailyContent
                    } else {
                        oneTimeContent
                    }

                    Spacer()

                    Button {
                        switch mode {
                        case .daily:   onConfirm(dailyTime, false)
                        case .oneTime: onConfirm(oneTimeDate, true)
                        }
                        dismiss()
                    } label: {
                        Text("Confirm").font(.system(size: 16, weight: .bold))
                            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                                .fill(Theme.accent).shadow(color: Theme.accent.opacity(0.42), radius: 16, x: 0, y: 5))
                    }
                    .buttonStyle(ListScaleStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar)
            .toolbarColorScheme(ThemeManager.shared.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.text1)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.r32)
        .presentationBackground(Theme.bg0)
    }

    @ViewBuilder
    private var dailyContent: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.10)).frame(width: 60, height: 60)
                    .shadow(color: Theme.accent.opacity(0.25), radius: 14, x: 0, y: 4)
                Image(systemName: "clock.fill").font(.system(size: 22, weight: .semibold)).foregroundColor(Theme.accent)
            }.padding(.top, 20)
            Text("Daily Reminder").font(.system(size: 17, weight: .bold)).foregroundColor(Theme.text0)
            Text("Fires every day at this time").font(.system(size: 12.5)).foregroundColor(Theme.text2)
            DatePicker("", selection: $dailyTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel).labelsHidden()
                .colorScheme(ThemeManager.shared.colorScheme)
        }
    }

    @ViewBuilder
    private var oneTimeContent: some View {
        VStack(spacing: 4) {
            Text("Pick a date and time")
                .font(.system(size: 12.5)).foregroundColor(Theme.text2)
                .padding(.top, 16)
            DatePicker("", selection: $oneTimeDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(ThemeManager.shared.colorScheme)
                .tint(Theme.accent)
                .padding(.horizontal, 8)
        }
    }

    private func modeTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? (ThemeManager.shared.isDark ? Color(hex: "#07080F") : .white) : Theme.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Theme.accent : .clear))
        }
        .buttonStyle(.plain)
    }
}

// ══════════════════════════════════════════════
// MARK: Shared Helpers
// ══════════════════════════════════════════════

private struct ReminderBanner: View {
    let time: Date
    let isOneTime: Bool
    let onClear: () -> Void

    private var label: String {
        isOneTime
            ? "One-time · \(kOneTimeDateFormatter.string(from: time))"
            : "Daily · \(kTimeFormatter.string(from: time))"
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bell.fill")
                .foregroundColor(Color(hex: "#2196F3"))
                .font(.system(size: 11))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            Text(label).font(.system(size: 12)).foregroundColor(Theme.text1)
            Spacer()
            Button(action: onClear) { Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(Theme.text2) }
                .buttonStyle(.plain)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
            .fill(Theme.accent.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.16), lineWidth: 0.5)))
    }
}

private struct ReminderConflictToast: View {
    let conflict: AppViewModel.ReminderConflictInfo
    @Binding var isVisible: Bool
    @State private var shakeOffset: CGFloat = 0

    private var message: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let timeStr = f.string(from: conflict.time)
        if let listName = conflict.listName {
            return "\"\(conflict.taskTitle)\" on \(listName) already has a notification for \(timeStr) — pick a different time to avoid conflicts."
        } else {
            return "\"\(conflict.taskTitle)\" already has a notification for \(timeStr) — pick a different time."
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.orange.opacity(0.15)))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.text0)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.text2)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Theme.bg3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bg1)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.orange.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .offset(x: shakeOffset)
        .onAppear { triggerShake() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func triggerShake() {
        let shakes: [(CGFloat, Double)] = [
            ( 6, 0.00), (-6, 0.07), ( 5, 0.14), (-5, 0.21),
            ( 3, 0.28), (-3, 0.35), ( 0, 0.42)
        ]
        for (offset, delay) in shakes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.5)) { shakeOffset = offset }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.25)) { isVisible = false }
        }
    }
}

private func sheetLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundColor(Theme.text1)
}

private func fieldBG(_ radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(Theme.bg2)
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
}

// MARK: - Preview

#Preview {
    ListManagementView()
        .environmentObject(AppViewModel())
        .environmentObject(ThemeManager.shared)
}
