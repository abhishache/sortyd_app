// MARK: - HealthTaskViews.swift
// Sortyd — HealthKit-linked task UI components

import SwiftUI
import HealthKit

// ══════════════════════════════════════════════
// MARK: SmallHealthDonut
// Small animated arc donut shown inline in task rows for health tasks.
// ══════════════════════════════════════════════

struct SmallHealthDonut: View {
    let taskType: HealthTaskType
    let target: Double
    let current: Double
    var size: CGFloat = 36

    @State private var drawn: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    private var pct: Int { Int((progress * 100).rounded()) }

    private var arcColor: Color {
        Color(hex: taskType.accentColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.bg3, lineWidth: size * 0.11)

            // Glow layer
            Circle()
                .trim(from: 0, to: drawn)
                .stroke(arcColor.opacity(0.18), lineWidth: size * 0.11 + 5)
                .rotationEffect(.degrees(-90))
                .blur(radius: 3)

            // Arc
            Circle()
                .trim(from: 0, to: drawn)
                .stroke(
                    AngularGradient(
                        colors: [arcColor.opacity(0.65), arcColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -1) {
                Image(systemName: taskType.icon)
                    .font(.system(size: size * 0.17, weight: .bold))
                    .foregroundColor(arcColor)
                Text("\(pct)%")
                    .font(.system(size: size * 0.19, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { drawn = progress }
        }
        .onChange(of: progress) { _, v in
            withAnimation(.easeOut(duration: 0.35)) { drawn = v }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: SmallHealthBar
// Vertical fill bar shown inline in task rows for health tasks.
// ══════════════════════════════════════════════

struct SmallHealthBar: View {
    let taskType: HealthTaskType
    let target: Double
    let current: Double
    var height: CGFloat = 44
    var tankWidth: CGFloat = 36

    @State private var filled: Double = 0
    @State private var waveAmplitude: CGFloat = 0
    @State private var waveOffset: CGFloat = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    private var arcColor: Color {
        Color(hex: taskType.accentColor)
    }

    var body: some View {
        ZStack {
            // Tank background
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.bg3)
                .frame(width: tankWidth, height: height)

            // Water fill with wave
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Glow behind fill
                    Rectangle()
                        .fill(arcColor.opacity(0.2))
                        .frame(height: geo.size.height * filled + 4)
                        .blur(radius: 5)

                    // Wave + fill shape
                    WaterWave(
                        progress: filled,
                        waveOffset: waveOffset,
                        amplitude: waveAmplitude
                    )
                    .fill(
                        LinearGradient(
                            colors: [arcColor, arcColor.opacity(0.8)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geo.size.height)
                }
            }
            .frame(width: tankWidth, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Icon — dim unfilled layer
            Image(systemName: taskType.icon)
                .font(.system(size: tankWidth * 0.55, weight: .bold))
                .foregroundColor(Theme.text0.opacity(0.22))
                .frame(width: tankWidth, height: height)

            // Icon — bright filled portion via bottom mask
            Image(systemName: taskType.icon)
                .font(.system(size: tankWidth * 0.55, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: arcColor.opacity(0.6), radius: 4, x: 0, y: 0)
                .mask(
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: geo.size.height * filled)
                        }
                    }
                )
                .frame(width: tankWidth, height: height)
        }
        .frame(width: tankWidth, height: height)
        .onAppear { triggerFillAnimation() }
        .onChange(of: progress) { _, _ in triggerFillAnimation() }
    }

    private func triggerFillAnimation() {
        // Reset wave to splashing state
        waveAmplitude = 6
        waveOffset = 0

        // Fill rises with spring
        withAnimation(.spring(response: 1.0, dampingFraction: 0.72).delay(0.1)) {
            filled = progress
        }

        // Wave sloshes: offset sweeps once then stops, amplitude decays to still
        withAnimation(.easeOut(duration: 1.2).delay(0.1)) {
            waveOffset = 1
        }
        withAnimation(.easeOut(duration: 1.8).delay(0.2)) {
            waveAmplitude = 0
        }
    }
}

// Sine-wave water shape
struct WaterWave: Shape {
    var progress: Double
    var waveOffset: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<Double, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(progress, waveOffset), amplitude) }
        set {
            progress  = newValue.first.first
            waveOffset = newValue.first.second
            amplitude  = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fillY = rect.height * (1 - progress)
        let waveLength = rect.width * 1.4

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: fillY))

        let steps = Int(rect.width) + 1
        for x in 0...steps {
            let relX = CGFloat(x) / rect.width
            let angle = (relX + waveOffset) * 2 * .pi * (rect.width / waveLength)
            let y = fillY + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// ══════════════════════════════════════════════
// MARK: HealthTargetBanner
// Shown inside AddTaskSheet when a health keyword is detected.
// ══════════════════════════════════════════════

struct HealthTargetBanner: View {
    @EnvironmentObject var vm: AppViewModel
    let taskType: HealthTaskType
    @Binding var targetText: String
    let onRequestPermission: () -> Void

    @StateObject private var hk = HealthKitManager.shared

    private var arcColor: Color { Color(hex: taskType.accentColor) }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(arcColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: taskType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(arcColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.appLanguage == .arabic ? "تم اكتشاف هدف صحي" : (vm.appLanguage == .spanish ? "Meta de salud detectada" : (vm.appLanguage == .chinese ? "检测到健康目标" : "Health Goal Detected")))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(arcColor)
                    Text(vm.appLanguage == .arabic ? "حدد هدفًا لتتبع التقدم باستخدام دونات مباشر" : (vm.appLanguage == .spanish ? "Establece un objetivo para seguir el progreso con un gráfico circular" : (vm.appLanguage == .chinese ? "设置目标以通过实时圆环追踪进度" : "Set a target to track progress with a live donut")))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text2)
                }
                Spacer()
                if taskType != .none {
                    if !hk.isAuthorized {
                        Button(action: onRequestPermission) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text(vm.appLanguage == .arabic ? "اتصال" : (vm.appLanguage == .spanish ? "Conectar" : (vm.appLanguage == .chinese ? "连接" : "Connect")))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(arcColor))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(arcColor)
                    }
                }
            }

            // Target input
            HStack(spacing: 8) {
                TextField(taskType.placeholder, text: $targetText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text0)
                Spacer()
                Button {
                    if taskType == .distance {
                        hk.distanceUnit = (hk.distanceUnit == .kilometers ? .miles : .kilometers)
                    }
                } label: {
                    Text(taskType.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(arcColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(arcColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(taskType != .distance)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                    .fill(Theme.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                            .strokeBorder(arcColor.opacity(0.3), lineWidth: 0.75)
                    )
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                .fill(arcColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                        .strokeBorder(arcColor.opacity(0.22), lineWidth: 0.75)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// ══════════════════════════════════════════════
// MARK: HealthPermissionSheet
// Lazy permission bottom sheet — only shown when a health task is first added.
// ══════════════════════════════════════════════

struct HealthPermissionSheet: View {
    @EnvironmentObject var vm: AppViewModel
    let taskType: HealthTaskType
    let onGrant: () -> Void
    let onSkip:  () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var hk = HealthKitManager.shared
    @State private var requesting = false

    private var arcColor: Color { Color(hex: taskType.accentColor) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button {
                        onSkip()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text(vm.localized("Cancel"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Theme.text1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                }
                .padding(.top, 12)
                .padding(.bottom, 20)

                ZStack {
                    Circle()
                        .fill(arcColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: taskType.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(arcColor)
                }
                .padding(.bottom, 16)

                Text(vm.appLanguage == .arabic ? "اتصل بـ Apple Health" : (vm.appLanguage == .spanish ? "Conectar con Apple Health" : (vm.appLanguage == .chinese ? "连接 Apple Health" : "Connect Apple Health")))
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Theme.text0)
                    .padding(.bottom, 8)

                Text(vm.appLanguage == .arabic ? "اكتشف Sortyd هدف **\(taskType.label.lowercased())** في مهمتك. اتصل بـ Health لرؤية دونات تقدم مباشر واحتسابه ضمن إكمالك العام." : (vm.appLanguage == .spanish ? "Sortyd detectó un objetivo de **\(taskType.label.lowercased())** en tu tarea. Conecta Health para ver un gráfico de progreso en vivo y sumarlo a tu completado general." : (vm.appLanguage == .chinese ? "Sortyd 在你的任务中检测到 **\(taskType.label.lowercased())** 目标。连接 Health 以查看实时进度圆环并计入整体完成度。" : "Sortyd detected a **\(taskType.label.lowercased())** goal in your task. Connect Health to see a live progress donut and count it toward your overall completion.")))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    pill(icon: "chart.bar.fill",
                         title: vm.appLanguage == .arabic ? "مؤشر دونات مباشر" : (vm.appLanguage == .spanish ? "Indicador de gráfico vivo" : (vm.appLanguage == .chinese ? "实时进度圆环" : "Live donut indicator")),
                         sub: vm.appLanguage == .arabic ? "تقدم القوس في الوقت الفعلي على كل صف مهمة" : (vm.appLanguage == .spanish ? "Progreso de arco en tiempo real en cada fila" : (vm.appLanguage == .chinese ? "每个任务行的实时弧形进度" : "Real-time arc progress on every task row")))
                    pill(icon: "percent",
                         title: vm.appLanguage == .arabic ? "يُحتسب ضمن نسبة القائمة" : (vm.appLanguage == .spanish ? "Cuenta para el % de la lista" : (vm.appLanguage == .chinese ? "计入列表完成度" : "Counts toward list %")),
                         sub: vm.appLanguage == .arabic ? "هدفك الصحي يدفع الإكمال العام" : (vm.appLanguage == .spanish ? "Tu meta de salud impulsa el completado general" : (vm.appLanguage == .chinese ? "健康目标推动整体完成进度" : "Your health goal drives overall completion")))
                    pill(icon: "lock.shield.fill",
                         title: vm.appLanguage == .arabic ? "وصول للقراءة فقط" : (vm.appLanguage == .spanish ? "Acceso de solo lectura" : (vm.appLanguage == .chinese ? "只读访问" : "Read-only access")),
                         sub: vm.appLanguage == .arabic ? "Sortyd لا يكتب أبدًا في Apple Health" : (vm.appLanguage == .spanish ? "Sortyd nunca escribe en Apple Health" : (vm.appLanguage == .chinese ? "Sortyd 从不向 Apple Health 写入数据" : "Sortyd never writes to Apple Health")))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                Button(action: {
                    requesting = true
                    Task {
                        let granted = await hk.requestPermission()
                        requesting = false
                        dismiss()
                        if granted { onGrant() } else { onSkip() }
                    }
                }) {
                    HStack(spacing: 8) {
                        if requesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(vm.appLanguage == .arabic ? "اتصل بـ Apple Health" : (vm.appLanguage == .spanish ? "Conectar con Apple Health" : (vm.appLanguage == .chinese ? "连接 Apple Health" : "Connect Apple Health")))
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [arcColor, arcColor.opacity(0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .disabled(requesting)

                Button(action: { dismiss(); onSkip() }) {
                    Text(vm.appLanguage == .arabic ? "تخطي الآن" : (vm.appLanguage == .spanish ? "Omitir por ahora" : (vm.appLanguage == .chinese ? "暂时跳过" : "Skip for now")))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text2)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
        .background(Theme.bg0)
    }

    @ViewBuilder
    private func pill(icon: String, title: LocalizedStringKey, sub: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(arcColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(arcColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text0)
                Text(sub).font(.system(size: 11)).foregroundColor(Theme.text2)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
    }
}
