import SwiftUI
import FirebaseAnalytics

// MARK: - Sortyd Onboarding v2
// Light + Dark mode fully supported. HealthKit disclosure compliant (Apple Guideline 2.5.1).

struct OnboardingShowcaseView: View {
    let onDismiss: () -> Void

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var currentPage    = 0
    @State private var launched       = false
    @State private var cardReady      = false
    @State private var buttonDown     = false
    @State private var meshShift:     CGFloat = 0
    @State private var logoFloat:     CGFloat = 0
    @State private var shimmerPhase:  CGFloat = 0
    @State private var particlePhase: CGFloat = 0
    @State private var glowPulse      = false
    @State private var logoRotate:    Double  = 0
    @State private var cardScale:     CGFloat = 0.93

    // 3D tilt state
    @State private var card3DTiltX:   CGFloat = 0
    @State private var card3DTiltY:   CGFloat = 0
    @State private var cardElevation: CGFloat = 0

    // MARK: Adaptive palette
    private var isDark: Bool { colorScheme == .dark }

    private var ink:       Color { isDark ? Color(hex: "#07080F") : Color(hex: "#F5F4FF") }
    private var inkMid:    Color { isDark ? Color(hex: "#0E1019") : Color(hex: "#ECEAF8") }
    private var cardBg:    Color { isDark ? Color(hex: "#10111C") : Color(hex: "#FFFFFF") }
    private var teal:      Color { Color(hex: "#3ECFFF") }
    private var violet:    Color { Color(hex: "#7C6FFF") }
    private var textPrimary:   Color { isDark ? Color(hex: "#DDE2FF") : Color(hex: "#0C0D20") }
    private var textSecondary: Color { isDark ? Color.white.opacity(0.40) : Color(hex: "#0C0D20").opacity(0.46) }
    private var textMuted:     Color { isDark ? Color.white.opacity(0.22) : Color(hex: "#0C0D20").opacity(0.28) }
    private var cardBorder:    Color { isDark ? teal.opacity(0.14) : Color(hex: "#5A4ECC").opacity(0.14) }
    private var separatorColor: Color { isDark ? Color.white.opacity(0.07) : Color(hex: "#0C0D20").opacity(0.07) }
    private var rowBg:         Color { isDark ? Color.white.opacity(0.025) : Color(hex: "#5A4ECC").opacity(0.03) }
    private var rowBorder:     Color { isDark ? Color.white.opacity(0.06) : Color(hex: "#5A4ECC").opacity(0.08) }
    private var progressTrack: Color { isDark ? Color.white.opacity(0.07) : Color(hex: "#5A4ECC").opacity(0.08) }
    private var blobTeal:      Color { isDark ? teal.opacity(0.10) : teal.opacity(0.06) }
    private var blobViolet:    Color { isDark ? violet.opacity(0.14) : violet.opacity(0.08) }

    private func l(_ key: String) -> String {
        switch vm.appLanguage {
        case .arabic:
            switch key {
            case "YOUR HABITS": return "عاداتك"
            case "Free forever": return "مجاني للأبد"
            case "Morning Routine": return "الروتين الصباحي"
            case "5 of 5": return "٥ من ٥"
            case "complete": return "مكتمل"
            case "Fitness": return "اللياقة"
            case "Learning": return "التعلم"
            case "Mindfulness": return "التأمل"
            case "TODAY": return "اليوم"
            case "Morning meditation": return "تأمل الصباح"
            case "Workout 30 min": return "تمرين ٣٠ دقيقة"
            case "Read 20 pages": return "قراءة ٢٠ صفحة"
            case "Journal entry": return "كتابة يوميات"
            case "Cold shower": return "دش بارد"
            case "done": return "تم"
            case "day streak": return "يوم متتالي"
            case "AI COACH INSIGHTS": return "رؤى مدرب الذكاء الاصطناعي"
            case "Mornings beat evenings by 2×": return "الصباح أفضل بمرتين"
            case "8am completion vs. 8pm — consistently": return "إكمال الساعة ٨ صباحاً مقابل ٨ مساءً — باستمرار"
            case "You skip Fridays 80% of the time": return "تتخطى أيام الجمعة ٨٠٪ من الوقت"
            case "Workout streak: personal best!": return "أفضل رقم شخصي للتمارين!"
            case "Grade": return "الدرجة"
            case "Weekly": return "أسبوعي"
            case "Streak": return "سلسلة"
            case "Continue": return "متابعة"
            case "Get Started": return "ابدأ الآن"
            default: return vm.localized(key)
            }
        case .spanish:
            switch key {
            case "YOUR HABITS": return "TUS HÁBITOS"
            case "Free forever": return "Gratis para siempre"
            case "Morning Routine": return "Rutina Mañanera"
            case "5 of 5": return "5 de 5"
            case "complete": return "completo"
            case "Fitness": return "Fitness"
            case "Learning": return "Aprendizaje"
            case "Mindfulness": return "Mindfulness"
            case "TODAY": return "HOY"
            case "Morning meditation": return "Meditación matutina"
            case "Workout 30 min": return "Entreno 30 min"
            case "Read 20 pages": return "Leer 20 páginas"
            case "Journal entry": return "Diario personal"
            case "Cold shower": return "Ducha fría"
            case "done": return "hecho"
            case "day streak": return "días seguidos"
            case "AI COACH INSIGHTS": return "RECOMENDACIONES DE IA"
            case "Mornings beat evenings by 2×": return "Mañanas rinden 2× más"
            case "8am completion vs. 8pm — consistently": return "Cumplimiento 8am vs 8pm — constante"
            case "You skip Fridays 80% of the time": return "Fallas los viernes un 80%"
            case "Workout streak: personal best!": return "¡Récord personal de entreno!"
            case "Grade": return "Nota"
            case "Weekly": return "Semanal"
            case "Streak": return "Racha"
            case "Continue": return "Continuar"
            case "Get Started": return "Empezar"
            default: return vm.localized(key)
            }
        default:
            return vm.localized(key)
        }
    }

    private var pages: [OBPage] {
        switch vm.appLanguage {
        case .arabic:
            return [
                OBPage(tag: 0,
                       headline: "اختر لغتك",
                       sub: "يمكنك تغيير هذا لاحقاً في إعدادات الآيفون.",
                       accentHex: "#3ECFFF"),
                OBPage(tag: 1,
                       headline: "نظم يومك",
                       sub: "نظم عاداتك في قوائم يومية. ركز على ما يهم، قائمة تلو الأخرى.",
                       accentHex: "#A78BFF"),
                OBPage(tag: 2,
                       headline: "تحليلات الذكاء الاصطناعي",
                       sub: "احصل على تحليل دقيق لسلوكك. يجد الذكاء الاصطناعي الأنماط التي تفوتك.",
                       accentHex: "#FF7EB3"),
                OBPage(tag: 3,
                       headline: "توصيل بـHealthKit",
                       sub: "زامِن خطواتك وسعراتك تلقائياً. شاهد تقدمك في الوقت الفعلي.",
                       accentHex: "#4FD1C5")
            ]
        case .spanish:
            return [
                OBPage(tag: 0,
                       headline: "Elige tu\nidioma",
                       sub: "Puedes cambiar esto más tarde en los Ajustes del iPhone.",
                       accentHex: "#3ECFFF"),
                OBPage(tag: 1,
                       headline: "Estructura\ntu día",
                       sub: "Agrupa hábitos en listas. Enfócate en lo que importa, una lista a la vez.",
                       accentHex: "#A78BFF"),
                OBPage(tag: 2,
                       headline: "Análisis con IA",
                       sub: "Obtén un desglose de tu comportamiento. La IA encuentra lo que tú no ves.",
                       accentHex: "#FF7EB3"),
                OBPage(tag: 3,
                       headline: "Salud de Apple",
                       sub: "Sincroniza pasos y calorías. Mira tu progreso en tiempo real.",
                       accentHex: "#4FD1C5")
            ]
        default:
            return [
                OBPage(tag: 0,
                       headline: "Choose your\nlanguage",
                       sub: "You can change this later in iPhone Settings.",
                       accentHex: "#3ECFFF"),
                OBPage(tag: 1,
                       headline: "Structure\nyour day",
                       sub: "Group habits into daily lists. Focus on what matters, one list at a time.",
                       accentHex: "#A78BFF"),
                OBPage(tag: 2,
                       headline: "AI-Powered\nInsights",
                       sub: "Get a sharp breakdown of your behavior. AI finds the patterns you miss.",
                       accentHex: "#FF7EB3"),
                OBPage(tag: 3,
                       headline: "HealthKit\nIntegration",
                       sub: "Sync your steps and calories automatically. See your progress in real-time.",
                       accentHex: "#4FD1C5")
            ]
        }
    }

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            meshAtmosphere.ignoresSafeArea().allowsHitTesting(false)
            floatingParticles.ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                logoHeader
                    .padding(.top, 36)
                    .padding(.bottom, 12)
                    .opacity(launched ? 1 : 0)
                    .offset(y: launched ? 0 : -16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.78), value: launched)

                showcaseCard
                    .padding(.horizontal, 20)
                    .scaleEffect(launched ? 1 : 0.92)
                    .opacity(launched ? 1 : 0)
                    .animation(.spring(response: 0.60, dampingFraction: 0.72).delay(0.08), value: launched)

                Spacer(minLength: 0)

                bottomSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .opacity(launched ? 1 : 0)
                    .offset(y: launched ? 0 : 26)
                    .animation(.spring(response: 0.58, dampingFraction: 0.76).delay(0.15), value: launched)
            }
        }
        .onAppear {
            Analytics.logEvent("onboarding_started", parameters: nil)
            withAnimation { launched = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true))  { glowPulse    = true }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true))  { logoFloat    = -6 }
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true))  { meshShift    = 1 }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false))    { shimmerPhase = 1 }
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true))  { particlePhase = 1 }

            // 3D floating tilt animations — subtle continuous sway
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true))  { card3DTiltX  = 1 }
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true))  { card3DTiltY  = 1 }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true))  { cardElevation = 1 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.72)) { cardReady = true }
            }
        }
    }

    // MARK: - Mesh Atmosphere

    private var meshAtmosphere: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [blobTeal, .clear],
                                        center: .center, startRadius: 0, endRadius: 220))
                    .frame(width: 440, height: 360).blur(radius: 55)
                    .offset(x: -70 + meshShift * 20, y: geo.size.height * 0.04 - meshShift * 10)
                Ellipse()
                    .fill(RadialGradient(colors: [blobViolet, .clear],
                                        center: .center, startRadius: 0, endRadius: 200))
                    .frame(width: 380, height: 340).blur(radius: 50)
                    .offset(x: geo.size.width * 0.52 - meshShift * 14,
                            y: geo.size.height * 0.56 + meshShift * 10)
                Circle()
                    .fill(RadialGradient(colors: [blobViolet.opacity(0.7), .clear],
                                        center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 240, height: 240).blur(radius: 40)
                    .offset(x: geo.size.width * 0.76, y: geo.size.height * 0.17 + meshShift * 8)
            }
        }
        .animation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true), value: meshShift)
    }

    // MARK: - Floating Particles

    private var floatingParticles: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    let cfg = particleConfig(i, geo: geo)
                    Circle()
                        .fill(cfg.color)
                        .frame(width: cfg.size, height: cfg.size)
                        .blur(radius: cfg.blur)
                        .offset(x: cfg.x, y: cfg.y - particlePhase * cfg.drift)
                        .opacity(particlePhase > 0 ? cfg.opacity : 0)
                }
            }
        }
        .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: particlePhase)
    }

    private struct ParticleCfg {
        let x, y, size, blur, drift, opacity: CGFloat
        let color: Color
    }

    private func particleConfig(_ i: Int, geo: GeometryProxy) -> ParticleCfg {
        let data: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Bool)] = [
            (0.10, 0.28, 4, 2, 55, 0.50, true),
            (0.86, 0.16, 3, 2, 75, 0.38, false),
            (0.22, 0.64, 3, 2, 48, 0.36, true),
            (0.70, 0.48, 5, 3, 68, 0.30, false),
            (0.42, 0.82, 3, 2, 88, 0.44, true),
            (0.62, 0.10, 3, 2, 52, 0.34, false),
            (0.06, 0.54, 3, 2, 62, 0.38, true),
            (0.90, 0.68, 4, 3, 72, 0.26, false),
            (0.34, 0.38, 3, 2, 44, 0.30, true),
            (0.78, 0.82, 3, 2, 60, 0.28, false)
        ]
        let c = data[i % data.count]
        let baseOpacity = isDark ? c.5 : c.5 * 0.6
        return ParticleCfg(
            x: geo.size.width  * c.0,
            y: geo.size.height * c.1,
            size: c.2, blur: c.3, drift: c.4, opacity: baseOpacity,
            color: c.6 ? teal.opacity(0.70) : violet.opacity(0.70)
        )
    }

    // MARK: - Logo Header

    private var logoHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                // Outer glow ring
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(teal.opacity(glowPulse ? 0.10 : 0.03))
                    .frame(width: 68, height: 68)
                    .blur(radius: 10)

                // Icon container — light-mode friendly with white bg + border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDark ? Color(hex: "#0E1019") : Color.white)
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: isDark
                                        ? [teal.opacity(0.45), violet.opacity(0.25)]
                                        : [teal.opacity(0.55), violet.opacity(0.35)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: isDark ? 1.0 : 1.5)
                    )
                    .shadow(
                        color: isDark ? .black.opacity(0.50) : Color(hex: "#5A4ECC").opacity(0.15),
                        radius: 12, x: 0, y: 4)
                    .shadow(color: teal.opacity(glowPulse ? 0.30 : 0.08),
                            radius: glowPulse ? 18 : 6, x: 0, y: 0)
                    // Shimmer sweep
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.clear, Color.white.opacity(isDark ? 0.09 : 0.55), .clear],
                                startPoint: .init(x: shimmerPhase - 0.6, y: 0),
                                endPoint:   .init(x: shimmerPhase + 0.4, y: 1)))
                            .blendMode(isDark ? .normal : .overlay)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Bar chart logo
                VStack(spacing: 5) {
                    logoBar(fill: 1.00, colors: [teal, violet])
                    logoBar(fill: 0.70, colors: [violet.opacity(0.80), teal.opacity(0.80)])
                    logoBar(fill: 0.38, colors: [violet.opacity(0.50), teal.opacity(0.50)])
                }
                .padding(.horizontal, 9)
                .frame(width: 54, height: 28)
            }
            .offset(y: logoFloat)
            .animation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true), value: logoFloat)

            Text("sortyd")
                .font(.system(size: 20, weight: .light, design: .rounded))
                .tracking(6)
                .foregroundColor(isDark ? Color.white.opacity(0.40) : Color(hex: "#1A1A2E").opacity(0.50))
        }
    }

    private func logoBar(fill: CGFloat, colors: [Color]) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.07) : Color(hex: "#5A4ECC").opacity(0.10))
                    .frame(height: 3.5)
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: g.size.width * fill, height: 3.5)
                    .shadow(color: teal.opacity(0.35), radius: 3)
            }
        }
        .frame(height: 3.5)
    }

    // MARK: - Showcase Card

    private var showcaseCard: some View {
        TabView(selection: $currentPage) {
            LanguageSelectCard(isDark: isDark).tag(0)
            Page0Card(teal: teal, violet: violet, cardReady: cardReady,
                      isActive: currentPage == 1, isDark: isDark, l: l).tag(1)
            Page1Card(teal: teal, violet: violet, cardReady: cardReady,
                      isActive: currentPage == 2, isDark: isDark, l: l).tag(2)
            Page2Card(teal: teal, violet: violet, cardReady: cardReady,
                      isActive: currentPage == 3, isDark: isDark, l: l).tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 300)
        // ── 3D floating tilt ──────────────────────────────────────────────
        // Gentle X-axis rock (forward/back lean)
        .rotation3DEffect(
            .degrees(card3DTiltX * 3.5),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.55
        )
        // Gentle Y-axis sway (left/right lean)
        .rotation3DEffect(
            .degrees(card3DTiltY * 2.8 - 1.4),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
        // Animated depth shadow that shifts with the tilt
        .shadow(
            color: teal.opacity(cardElevation > 0.5 ? 0.28 : 0.10),
            radius: cardElevation > 0.5 ? 28 : 10,
            x: card3DTiltY * -8,
            y: card3DTiltX * 12 + 6
        )
        .shadow(
            color: violet.opacity(cardElevation > 0.5 ? 0.18 : 0.06),
            radius: cardElevation > 0.5 ? 18 : 6,
            x: card3DTiltY * 5,
            y: card3DTiltX * 8 + 3
        )
        // Subtle Z-scale breathe that sells the floating feel
        .scaleEffect(1.0 + cardElevation * 0.012)
        .animation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: card3DTiltX)
        .animation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true), value: card3DTiltY)
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: cardElevation)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            pageDots.padding(.bottom, 18)

            // Headline — gradient on keyword portion only
            Group {
                let headline = pages[currentPage].headline
                let parts = headline.components(separatedBy: "\n")
                VStack(spacing: 2) {
                    Text(parts[0])
                        .foregroundColor(textPrimary)
                    if parts.count > 1 {
                        Text(parts[1])
                            .foregroundStyle(LinearGradient(
                                colors: [teal, violet],
                                startPoint: .leading, endPoint: .trailing))
                    }
                }
            }
            .font(.system(size: 26, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(height: 68, alignment: .top)
            .id("hl-\(currentPage)")
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)))
            .animation(.spring(response: 0.40, dampingFraction: 0.80), value: currentPage)

            Text(pages[currentPage].sub)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36, alignment: .top)
                .padding(.top, 4)
                .id("sub-\(currentPage)")
                .transition(.opacity)
                .animation(.easeOut(duration: 0.26).delay(0.06), value: currentPage)

            Spacer(minLength: 10)

            // HealthKit compliance badge — prominent, above CTA
            // Apple Guideline 2.5.1: must clearly identify HealthKit functionality
            healthKitDisclosure.padding(.bottom, 10)

            // AI disclaimer
            Text({
                switch vm.appLanguage {
                case .arabic: return "تستخدم رؤى الذكاء الاصطناعي عناوين العادات فقط - تتم معالجتها بأمان."
                case .spanish: return "La IA solo usa títulos de hábitos — procesados de forma segura."
                default: return "AI insights use habit titles only — processed securely, never sold."
                }
            }())
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.90)
                .padding(.bottom, 10)

            ctaButton
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i == currentPage
                          ? AnyShapeStyle(LinearGradient(colors: [teal, violet],
                                           startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(isDark
                                          ? Color.white.opacity(0.12)
                                          : Color(hex: "#5A4ECC").opacity(0.18)))
                    .frame(width: i == currentPage ? 22 : 5, height: 5)
                    .animation(.spring(response: 0.36, dampingFraction: 0.68), value: currentPage)
            }
        }
    }

    // MARK: - HealthKit Disclosure (Apple Guideline 2.5.1 — prominent & descriptive)

    private var healthKitDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "#FF375F").opacity(isDark ? 0.16 : 0.10))
                        .frame(width: 30, height: 30)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF375F"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text({
                        switch vm.appLanguage {
                        case .arabic: return "يستخدم Apple HealthKit"
                        case .spanish: return "Usa Apple HealthKit"
                        default: return "Uses Apple HealthKit"
                        }
                    }())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.82) : Color(hex: "#1A1A2E").opacity(0.85))
                    Text({
                        switch vm.appLanguage {
                        case .arabic: return "يقرأ الخطوات والسعرات لتتبع العادات اللياقة البدنية"
                        case .spanish: return "Lee pasos y calorías para rastrear hábitos de fitness"
                        default: return "Reads steps & active calories to track fitness habits"
                        }
                    }())
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.40) : Color(hex: "#1A1A2E").opacity(0.46))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF375F").opacity(0.70))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#FF375F").opacity(isDark ? 0.07 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#FF375F").opacity(isDark ? 0.18 : 0.14), lineWidth: 0.8)
                )
        )
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.52)) { buttonDown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) { buttonDown = false }
            }
            if currentPage < 3 {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    currentPage += 1
                    cardReady = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.72)) { cardReady = true }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentPage == 3 ? l("Get Started") : l("Continue"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .animation(nil, value: currentPage)
                Image(systemName: "arrow.right")
                    .flipsForRightToLeftLayoutDirection(true)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [teal, violet],
                        startPoint: .leading, endPoint: .trailing))
            )
            .clipShape(Capsule())
            .shadow(color: teal.opacity(glowPulse ? 0.35 : 0.12),
                    radius: glowPulse ? 12 : 6, y: 4)
            .shadow(color: violet.opacity(glowPulse ? 0.20 : 0.08),
                    radius: glowPulse ? 8 : 4, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(buttonDown ? 0.97 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.58), value: buttonDown)
    }

    // MARK: - Data Model

    private struct OBPage {
        let tag: Int
        let headline: String
        let sub: String
        let accentHex: String
    }

    // MARK: - Language Select Page

    private struct LanguageSelectCard: View {
        @EnvironmentObject var vm: AppViewModel
        let isDark: Bool

        var body: some View {
            ZStack {
                AdaptiveCardBase(top: Color(hex: "#3ECFFF"), bottom: Color(hex: "#7C6FFF"), isDark: isDark)

                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            vm.setLanguage(lang)
                        } label: {
                            HStack {
                                Text(lang.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                if vm.appLanguage == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "#3ECFFF"))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(vm.appLanguage == lang ? Color(hex: "#3ECFFF") : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Page 0: Habits

    private struct Page0Card: View {
        @EnvironmentObject var vm: AppViewModel
        let teal: Color
        let violet: Color
        let cardReady: Bool
        let isActive: Bool
        let isDark: Bool
        let l: (String) -> String

        @State private var innerTilt: CGFloat = 0

        private var cardBg:      Color { isDark ? Color(hex: "#10111C") : Color.white }
        private var cardBorder:  Color { isDark ? Color(hex: "#3ECFFF").opacity(0.14) : Color(hex: "#5A4ECC").opacity(0.14) }
        private var trackBg:     Color { isDark ? Color.white.opacity(0.07) : Color(hex: "#5A4ECC").opacity(0.08) }
        private var supportText: Color { isDark ? Color.white.opacity(0.42) : Color(hex: "#0C0D20").opacity(0.46) }
        private var supportPct:  Color { isDark ? Color.white.opacity(0.24) : Color(hex: "#0C0D20").opacity(0.28) }

        var body: some View {
            ZStack(alignment: .topLeading) {
                AdaptiveCardBase(top: teal, bottom: violet, isDark: isDark)

                // Inner gloss highlight — sells the 3D convex surface
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(isDark ? 0.07 : 0.50), .clear],
                        startPoint: .topLeading,
                        endPoint: .init(x: 0.5, y: 0.4)))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        eyebrow(icon: "square.stack.3d.up.fill",
                                label: l("YOUR HABITS"), color: teal)
                        Spacer()
                        freePill
                    }
                    .padding(.bottom, 10)

                    heroRow.padding(.bottom, 10)

                    VStack(spacing: 6) {
                        supportRow(emoji: "💪", name: l("Fitness"),     pct: 0.72, delay: 1)
                        supportRow(emoji: "📚", name: l("Learning"),    pct: 0.40, delay: 2)
                        supportRow(emoji: "🧘", name: l("Mindfulness"), pct: 0.60, delay: 3)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            // Per-card entry lift with 3D flip-up entrance
            .rotation3DEffect(
                .degrees(cardReady ? 0 : -8),
                axis: (x: 1, y: 0.2, z: 0),
                perspective: 0.5
            )
            .scaleEffect(cardReady ? 1.0 : 0.95)
            .animation(.spring(response: 0.55, dampingFraction: 0.70), value: cardReady)
        }

        private func eyebrow(icon: String, label: String, color: Color) -> some View {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(2.0).foregroundColor(color.opacity(0.85))
            }
        }

        private var freePill: some View {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 9)).foregroundColor(teal)
                Text(l("Free forever"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? Color.white.opacity(0.45) : Color(hex: "#0C0D20").opacity(0.48))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                Capsule().fill(teal.opacity(0.08))
                    .overlay(Capsule().strokeBorder(teal.opacity(0.22), lineWidth: 0.6))
            )
        }

        private var heroRow: some View {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(teal.opacity(0.14)).frame(width: 38, height: 38)
                    Text("🌅").font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(l("Morning Routine"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(isDark ? .white : Color(hex: "#0C0D20"))
                        Spacer()
                        Text("100%")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(
                                colors: [teal, violet],
                                startPoint: .leading, endPoint: .trailing))
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(trackBg).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [teal, violet],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: cardReady ? g.size.width : 0, height: 4)
                                .shadow(color: teal.opacity(0.45), radius: 5)
                                .animation(.easeOut(duration: 0.90).delay(0.08), value: cardReady)
                        }
                    }.frame(height: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9)).foregroundColor(teal)
                        Text("\(l("5 of 5")) \(l("complete"))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(isDark ? Color.white.opacity(0.48) : Color(hex: "#0C0D20").opacity(0.46))
                    }
                    .opacity(cardReady ? 1 : 0)
                    .animation(.easeOut.delay(0.36), value: cardReady)
                }
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(teal.opacity(isDark ? 0.07 : 0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [teal.opacity(0.40), teal.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isDark ? 1 : 1.2))
            )
            .shadow(color: isDark ? teal.opacity(0.10) : Color(hex: "#5A4ECC").opacity(0.12), radius: 10)
            .opacity(cardReady ? 1 : 0)
            .scaleEffect(cardReady ? 1 : 0.96)
            .animation(.spring(response: 0.44, dampingFraction: 0.76).delay(0.05), value: cardReady)
        }

        private func supportRow(emoji: String, name: String, pct: CGFloat, delay: Int) -> some View {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 13))
                Text(name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(supportText)
                Spacer()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackBg).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [violet.opacity(0.75), teal.opacity(0.75)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: cardReady ? g.size.width * pct : 0, height: 3)
                            .animation(.easeOut(duration: 0.80).delay(Double(delay) * 0.09 + 0.22),
                                       value: cardReady)
                    }
                }.frame(width: 74, height: 3)
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(supportPct)
                    .frame(width: 24, alignment: .trailing)
            }
            .opacity(cardReady ? 1 : 0)
            .offset(x: cardReady ? 0 : 16)
            .animation(.spring(response: 0.44, dampingFraction: 0.74)
                        .delay(Double(delay) * 0.08 + 0.20), value: cardReady)
        }
    }

    // MARK: - Page 1: Today & Streak

    private struct Page1Card: View {
        @EnvironmentObject var vm: AppViewModel
        let teal: Color
        let violet: Color
        let cardReady: Bool
        let isActive: Bool
        let isDark: Bool
        let l: (String) -> String

        private var eyebrowColor: Color { isDark ? Color(hex: "#7C6FFF").opacity(0.85) : Color(hex: "#5A4ECC").opacity(0.85) }
        private var divColor:     Color { isDark ? Color.white.opacity(0.05) : Color(hex: "#0C0D20").opacity(0.05) }
        private var sepColor:     Color { isDark ? Color.white.opacity(0.07) : Color(hex: "#0C0D20").opacity(0.07) }
        private var footerBg1:   Color { isDark ? Color.white.opacity(0.04) : Color(hex: "#5A4ECC").opacity(0.03) }
        private var footerBg2:   Color { isDark ? Color.white.opacity(0.02) : Color(hex: "#5A4ECC").opacity(0.015) }

        private var tasks: [(String, Bool)] {
            [
                (l("Morning meditation"), true),
                (l("Workout 30 min"),     true),
                (l("Read 20 pages"),      true),
                (l("Journal entry"),      false),
                (l("Cold shower"),        false)
            ]
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                AdaptiveCardBase(top: violet, bottom: teal, isDark: isDark)

                // Inner gloss highlight
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(isDark ? 0.07 : 0.50), .clear],
                        startPoint: .topLeading,
                        endPoint: .init(x: 0.5, y: 0.4)))
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9)).foregroundColor(violet)
                            Text(l("TODAY"))
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(2.0).foregroundColor(eyebrowColor)
                        }
                        .padding(.bottom, 11)

                        VStack(spacing: 0) {
                            ForEach(Array(tasks.enumerated()), id: \.offset) { idx, task in
                                taskRow(task.0, done: task.1, idx: idx)
                                if idx < tasks.count - 1 {
                                    Rectangle()
                                        .fill(divColor)
                                        .frame(height: 0.5)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                    streakHero
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Per-card entry lift with 3D flip-up entrance
            .rotation3DEffect(
                .degrees(cardReady ? 0 : -8),
                axis: (x: 1, y: -0.2, z: 0),
                perspective: 0.5
            )
            .scaleEffect(cardReady ? 1.0 : 0.95)
            .animation(.spring(response: 0.55, dampingFraction: 0.70), value: cardReady)
        }

        private func taskRow(_ title: String, done: Bool, idx: Int) -> some View {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? teal : (isDark ? Color.white.opacity(0.15) : Color(hex: "#0C0D20").opacity(0.20)),
                                      lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                    if done {
                        Circle().fill(teal).frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.system(size: 6, weight: .black))
                            .foregroundColor(Color(hex: "#0A0B14"))
                    }
                }
                .scaleEffect(cardReady && done ? 1 : (done ? 0.30 : 1))
                .animation(.spring(response: 0.30, dampingFraction: 0.50).delay(Double(idx) * 0.06 + 0.18),
                           value: cardReady)

                Text(title)
                    .font(.system(size: 11, weight: done ? .regular : .medium, design: .rounded))
                    .foregroundColor(done
                        ? (isDark ? Color.white.opacity(0.26) : Color(hex: "#0C0D20").opacity(0.28))
                        : (isDark ? Color.white.opacity(0.82) : Color(hex: "#0C0D20").opacity(0.84)))
                    .strikethrough(done, color: isDark ? Color.white.opacity(0.18) : Color(hex: "#0C0D20").opacity(0.18))
                Spacer()
            }
            .padding(.vertical, 5.5)
            .opacity(cardReady ? 1 : 0)
            .animation(.easeOut(duration: 0.28).delay(Double(idx) * 0.055 + 0.12), value: cardReady)
        }

        private var streakHero: some View {
            HStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isDark ? Color.white.opacity(0.08) : Color(hex: "#5A4ECC").opacity(0.10),
                                lineWidth: 5.5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: cardReady ? 0.60 : 0)
                        .stroke(AngularGradient(colors: [teal, violet, teal], center: .center),
                                style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                        .animation(.easeOut(duration: 1.0).delay(0.24), value: cardReady)
                    VStack(spacing: -2) {
                        Text("3/5")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(isDark ? .white : Color(hex: "#0C0D20"))
                        Text(l("done"))
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(teal)
                    }
                    .opacity(cardReady ? 1 : 0)
                    .animation(.easeOut.delay(0.42), value: cardReady)
                }
                .padding(.trailing, 16)

                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.08) : Color(hex: "#0C0D20").opacity(0.08))
                    .frame(width: 0.5, height: 44)
                    .padding(.trailing, 16)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .scaleEffect(cardReady ? 1 : 0.35)
                            .animation(.spring(response: 0.34, dampingFraction: 0.48).delay(0.48), value: cardReady)
                        Text("12")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(isDark ? .white : Color(hex: "#0C0D20"))
                    }
                    Text(l("day streak"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.38) : Color(hex: "#0C0D20").opacity(0.42))
                }
                .opacity(cardReady ? 1 : 0)
                .animation(.easeOut.delay(0.52), value: cardReady)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                ZStack(alignment: .top) {
                    LinearGradient(colors: [footerBg1, footerBg2], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(sepColor).frame(height: 0.5)
                }
            )
        }
    }

    // MARK: - Page 2: AI Insights

    private struct Page2Card: View {
        @EnvironmentObject var vm: AppViewModel
        let teal: Color
        let violet: Color
        let cardReady: Bool
        let isActive: Bool
        let isDark: Bool
        let l: (String) -> String

        private let insights: [(String, String, String)] = [
            ("Mornings beat evenings by 2×",     "sun.max.fill", "#FFD60A"),
            ("You skip Fridays 80% of the time", "flame.fill",   "#FF6B35"),
            ("Workout streak: personal best!",   "trophy.fill",  "#3ECFFF")
        ]
        private let stats: [(String, String, String)] = [
            ("B+",  "Grade",  "#3ECFFF"),
            ("78%", "Weekly", "#7C6FFF"),
            ("12d", "Streak", "#FF6B35")
        ]

        private var rowBg:     Color { isDark ? Color.white.opacity(0.025) : Color(hex: "#5A4ECC").opacity(0.025) }
        private var rowBorder: Color { isDark ? Color.white.opacity(0.06) : Color(hex: "#5A4ECC").opacity(0.08) }
        private var secText:   Color { isDark ? Color.white.opacity(0.55) : Color(hex: "#0C0D20").opacity(0.58) }

        var body: some View {
            ZStack(alignment: .topLeading) {
                AdaptiveCardBase(top: violet, bottom: teal, isDark: isDark)

                // Inner gloss highlight
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(isDark ? 0.07 : 0.50), .clear],
                        startPoint: .topLeading,
                        endPoint: .init(x: 0.5, y: 0.4)))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(violet)
                        Text(l("AI COACH INSIGHTS"))
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(2.0)
                            .foregroundColor(isDark ? violet.opacity(0.85) : Color(hex: "#5A4ECC").opacity(0.90))
                    }
                    featuredInsight
                    VStack(spacing: 4) {
                    secondaryRow(text: l(insights[1].0), icon: insights[1].1,
                                 color: Color(hex: insights[1].2), delay: 1)
                    secondaryRow(text: l(insights[2].0), icon: insights[2].1,
                                 color: Color(hex: insights[2].2), delay: 2)
                    }
                    HStack(spacing: 6) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { idx, s in
                            statPill(value: s.0, label: l(s.1), color: Color(hex: s.2), delay: idx)
                        }
                    }
                }
                .padding(17)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            // Per-card entry lift with 3D flip-up entrance
            .rotation3DEffect(
                .degrees(cardReady ? 0 : -8),
                axis: (x: 1, y: 0.3, z: 0),
                perspective: 0.5
            )
            .scaleEffect(cardReady ? 1.0 : 0.95)
            .animation(.spring(response: 0.55, dampingFraction: 0.70), value: cardReady)
        }

        private var featuredInsight: some View {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#FFD60A").opacity(0.14)).frame(width: 38, height: 38)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FFD60A"))
                }
                .scaleEffect(cardReady ? 1 : 0.50)
                .animation(.spring(response: 0.36, dampingFraction: 0.52).delay(0.10), value: cardReady)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l("Mornings beat evenings by 2×"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.92) : Color(hex: "#0C0D20").opacity(0.90))
                    Text(l("8am completion vs. 8pm — consistently"))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.38) : Color(hex: "#0C0D20").opacity(0.42))
                }
                Spacer()
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(hex: "#FFD60A").opacity(isDark ? 0.06 : 0.05))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color(hex: "#FFD60A").opacity(isDark ? 0.22 : 0.20), lineWidth: 0.8))
            )
            .opacity(cardReady ? 1 : 0)
            .offset(y: cardReady ? 0 : 10)
            .animation(.spring(response: 0.42, dampingFraction: 0.76).delay(0.08), value: cardReady)
        }

        private func secondaryRow(text: String, icon: String, color: Color, delay: Int) -> some View {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.10)).frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 10)).foregroundColor(color)
                }
                Text(text)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(secText)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(rowBg)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(rowBorder, lineWidth: 0.5))
            )
            .opacity(cardReady ? 1 : 0)
            .offset(y: cardReady ? 0 : 10)
            .animation(.spring(response: 0.42, dampingFraction: 0.74)
                        .delay(Double(delay) * 0.08 + 0.14), value: cardReady)
        }

        private func statPill(value: String, label: String, color: Color, delay: Int) -> some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(isDark ? Color.white.opacity(0.34) : Color(hex: "#0C0D20").opacity(0.38))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(color.opacity(isDark ? 0.16 : 0.20), lineWidth: 0.5))
            )
            .opacity(cardReady ? 1 : 0)
            .scaleEffect(cardReady ? 1 : 0.78)
            .animation(.spring(response: 0.34, dampingFraction: 0.62)
                        .delay(Double(delay) * 0.09 + 0.38), value: cardReady)
        }
    }
}

// MARK: - Adaptive Card Base (light + dark)

struct AdaptiveCardBase: View {
    let top: Color
    let bottom: Color
    let isDark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(isDark ? Color(hex: "#10111C") : Color.white)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [top.opacity(isDark ? 0.07 : 0.04), bottom.opacity(isDark ? 0.03 : 0.02), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isDark
                            ? [top.opacity(0.34), bottom.opacity(0.14), Color.white.opacity(0.04)]
                            : [top.opacity(0.28), bottom.opacity(0.12), Color(hex: "#5A4ECC").opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isDark ? 2.0 : 2.4)
            // Bottom drop shadow baked into the card for 3D depth
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [.clear, bottom.opacity(isDark ? 0.18 : 0.10)],
                    startPoint: .top, endPoint: .bottom))
                .blendMode(.normal)
                .allowsHitTesting(false)
        }
    }
}


// MARK: - Preview

#Preview("Dark") {
    OnboardingShowcaseView(onDismiss: {})
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager.shared)
        .environmentObject(AppViewModel())
}

#Preview("Light") {
    OnboardingShowcaseView(onDismiss: {})
        .preferredColorScheme(.light)
        .environmentObject(ThemeManager.shared)
        .environmentObject(AppViewModel())
}
