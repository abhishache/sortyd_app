import SwiftUI

// MARK: - Sortyd Onboarding Showcase

struct OnboardingShowcaseView: View {
    let onDismiss: () -> Void
    
    @State private var currentPage = 0
    @State private var launched = false
    @State private var cardReady = false
    
    // Ambient animation states
    @State private var meshShift: CGFloat = 0
    @State private var glowBreath = false
    @State private var logoFloat: CGFloat = 0
    
    private let teal   = Color(hex: "#3ECFFF")
    private let violet = Color(hex: "#7C6FFF")
    private let ink    = Color(hex: "#0C0D16")
    private let inkMid = Color(hex: "#13141F")
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            tag: 0,
            headline: "Build the life\nyou keep\npromising yourself.",
            sub: "Sortyd turns your intentions into systems — no subscriptions, no paywalls, ever.",
            accentColor: "#3ECFFF"
        ),
        OnboardingPage(
            tag: 1,
            headline: "Every habit.\nEvery streak.\nOne tap.",
            sub: "Morning routine to midnight wind-down — track everything that shapes who you're becoming.",
            accentColor: "#7C6FFF"
        ),
        OnboardingPage(
            tag: 2,
            headline: "Your AI coach\nreads the\npatterns you miss.",
            sub: "Sortyd's AI studies your data and tells you exactly what to shift — backed by your own results.",
            accentColor: "#3ECFFF"
        )
    ]
    
    var body: some View {
        ZStack {
            // ── Deep background ──
            ink.ignoresSafeArea()
            
            // ── Animated mesh gradient atmosphere ──
            meshAtmosphere
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // ── Grain overlay ──
            grainOverlay
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // ── Main content ──
            VStack(spacing: 0) {
                
                // ── Top: Logo + wordmark ──
                logoHeader
                    .padding(.top, 54)
                    .offset(y: launched ? 0 : -20)
                    .opacity(launched ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: launched)
                
                Spacer(minLength: 0)
                
                // ── Center: Visual showcase card ──
                showcaseCard
                    .padding(.horizontal, 24)
                    .scaleEffect(launched ? 1 : 0.92)
                    .opacity(launched ? 1 : 0)
                    .animation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.1), value: launched)
                
                Spacer(minLength: 0)
                
                // ── Bottom: Page text + dots + CTA ──
                bottomSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 44)
                    .offset(y: launched ? 0 : 30)
                    .opacity(launched ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.18), value: launched)
            }
        }
        .onAppear {
            withAnimation { launched = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glowBreath = true }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { logoFloat = -6 }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { meshShift = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.4)) { cardReady = true }
            }
        }
    }
    
    // MARK: - Mesh Atmosphere
    
    private var meshAtmosphere: some View {
        GeometryReader { geo in
            ZStack {
                // Teal blob — top left
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [teal.opacity(0.18), teal.opacity(0)],
                            center: .center, startRadius: 0, endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 380)
                    .blur(radius: 60)
                    .offset(
                        x: -80 + meshShift * 20,
                        y: geo.size.height * 0.08 - meshShift * 10
                    )
                
                // Violet blob — bottom right
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [violet.opacity(0.22), violet.opacity(0)],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 360)
                    .blur(radius: 55)
                    .offset(
                        x: geo.size.width * 0.55 - meshShift * 15,
                        y: geo.size.height * 0.58 + meshShift * 12
                    )
                
                // Secondary teal — mid
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [teal.opacity(0.10), teal.opacity(0)],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 40)
                    .offset(
                        x: geo.size.width * 0.7,
                        y: geo.size.height * 0.2 + meshShift * 8
                    )
            }
        }
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: meshShift)
    }
    
    // MARK: - Grain Overlay
    
    private var grainOverlay: some View {
        Rectangle()
            .fill(
                Color.white.opacity(0.025)
            )
            .background(
                // Subtle vignette
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.35)],
                    center: .center, startRadius: 100, endRadius: 420
                )
            )
    }
    
    // MARK: - Logo Header
    
    private var logoHeader: some View {
        VStack(spacing: 8) {
            // App icon mark (SVG bars distilled into SwiftUI)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(inkMid)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [teal.opacity(0.35), violet.opacity(0.25)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: teal.opacity(glowBreath ? 0.3 : 0.12), radius: glowBreath ? 18 : 10)
                
                VStack(spacing: 5) {
                    barMark(fill: 1.0, gradient: [teal, violet])
                    barMark(fill: 0.72, gradient: [violet.opacity(0.85), teal.opacity(0.85)])
                    barMark(fill: 0.40, gradient: [violet.opacity(0.5), teal.opacity(0.5)])
                }
                .padding(.horizontal, 10)
                .frame(width: 52, height: 28)
            }
            .offset(y: logoFloat)
            .animation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: logoFloat)
            
            Text("sortyd")
                .font(.system(size: 13, weight: .light, design: .default))
                .tracking(6)
                .foregroundColor(.white.opacity(0.55))
        }
    }
    
    private func barMark(fill: CGFloat, gradient: [Color]) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * fill, height: 4)
            }
        }
        .frame(height: 4)
    }
    
    // MARK: - Showcase Card
    
    private var showcaseCard: some View {
        TabView(selection: $currentPage) {
            Page0Card(teal: teal, violet: violet, ink: inkMid, cardReady: cardReady, isActive: currentPage == 0)
                .tag(0)
            Page1Card(teal: teal, violet: violet, ink: inkMid, cardReady: cardReady, isActive: currentPage == 1)
                .tag(1)
            Page2Card(teal: teal, violet: violet, ink: inkMid, cardReady: cardReady, isActive: currentPage == 2)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 310)
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Headline + sub
            VStack(spacing: 10) {
                Text(pages[currentPage].headline)
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("headline-\(currentPage)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.42, dampingFraction: 0.8), value: currentPage)
                
                Text(pages[currentPage].sub)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("sub-\(currentPage)")
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.35).delay(0.08), value: currentPage)
            }
            .padding(.bottom, 28)
            
            // Page dots
            HStack(spacing: 7) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == currentPage
                              ? LinearGradient(colors: [teal, violet], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.15)],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: i == currentPage ? 28 : 6, height: 6)
                        .animation(.spring(response: 0.38, dampingFraction: 0.68), value: currentPage)
                }
            }
            .padding(.bottom, 28)
            
            // CTA
            ctaButton
        }
    }
    
    // MARK: - CTA Button
    
    @State private var buttonDown = false
    
    private var ctaButton: some View {
        VStack(spacing: 0) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) { buttonDown = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { buttonDown = false }
                }
                
                if currentPage < 2 {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        currentPage += 1
                        cardReady = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeOut(duration: 0.38)) { cardReady = true }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDismiss() }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage == 2 ? "Start building" : "Continue")
                        .font(.system(size: 16, weight: .bold))
                        .animation(nil, value: currentPage)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [teal, violet],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        // Shine strip
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .offset(y: -8)
                    }
                )
                .clipShape(Capsule())
                .shadow(color: teal.opacity(glowBreath ? 0.45 : 0.22), radius: glowBreath ? 22 : 12, y: 8)
            }
            .buttonStyle(.plain)
            .scaleEffect(buttonDown ? 0.96 : 1.0)
            
            if currentPage == 2 {
                Text("AI coaching sends your task titles to a secure third-party server to generate insights. No data is sold or shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Data Model
    
    private struct OnboardingPage {
        let tag: Int
        let headline: String
        let sub: String
        let accentColor: String
    }
    
    // MARK: - Page 0: Create Lists
    
    private struct Page0Card: View {
        let teal: Color
        let violet: Color
        let ink: Color
        let cardReady: Bool
        let isActive: Bool
        
        @State private var pulse = false
        
        var body: some View {
            ZStack {
                // Glass card
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(hex: "#13141F").opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [teal.opacity(0.22), violet.opacity(0.14), Color.white.opacity(0.06)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header label
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(teal)
                        Text("YOUR HABITS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(teal.opacity(0.8))
                    }
                    .padding(.bottom, 16)
                    
                    VStack(spacing: 8) {
                        listRow(emoji: "🌅", name: "Morning Routine", count: 5, pct: 1.0, active: true,  delay: 0)
                        listRow(emoji: "💪", name: "Fitness",          count: 4, pct: 0.72, active: false, delay: 1)
                        listRow(emoji: "📚", name: "Learning",         count: 3, pct: 0.40, active: false, delay: 2)
                        listRow(emoji: "🧘", name: "Mindfulness",      count: 3, pct: 0.60, active: false, delay: 3)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Free badge
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(teal)
                        Text("100% Free · No limits")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .opacity(cardReady ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: cardReady)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(15)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        
        private func listRow(emoji: String, name: String, count: Int, pct: CGFloat, active: Bool, delay: Int) -> some View {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? teal.opacity(0.1) : Color.white.opacity(0.05))
                        .frame(width: 34, height: 34)
                    Text(emoji).font(.system(size: 17))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(active ? teal : .white.opacity(0.35))
                    }
                    
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(colors: [teal, violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: cardReady ? g.size.width * pct : 0, height: 3)
                                .animation(.easeOut(duration: 0.9).delay(Double(delay) * 0.1 + 0.2), value: cardReady)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? teal.opacity(0.06) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(active ? teal.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .opacity(cardReady ? 1 : 0)
            .offset(x: cardReady ? 0 : 24)
            .animation(.spring(response: 0.48, dampingFraction: 0.75).delay(Double(delay) * 0.08 + 0.15), value: cardReady)
        }
    }
    
    // MARK: - Page 1: Track & Streak
    
    private struct Page1Card: View {
        let teal: Color
        let violet: Color
        let ink: Color
        let cardReady: Bool
        let isActive: Bool
        
        private let tasks = [
            ("Morning meditation", true),
            ("Workout 30 min",      true),
            ("Read 20 pages",       true),
            ("Journal entry",       false),
            ("Cold shower",         false)
        ]
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(hex: "#13141F").opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [violet.opacity(0.22), teal.opacity(0.14), Color.white.opacity(0.06)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        // Left: task list
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(violet)
                                Text("TODAY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(violet.opacity(0.8))
                            }
                            .padding(.bottom, 14)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(tasks.enumerated()), id: \.offset) { idx, task in
                                    taskRow(task.0, done: task.1, idx: idx)
                                    if idx < tasks.count - 1 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 0.5)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right: ring stat
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                                    .frame(width: 70, height: 70)
                                Circle()
                                    .trim(from: 0, to: cardReady ? 0.6 : 0)
                                    .stroke(
                                        AngularGradient(colors: [teal, violet, teal], center: .center),
                                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 70, height: 70)
                                    .animation(.easeOut(duration: 1.1).delay(0.25), value: cardReady)
                                VStack(spacing: -1) {
                                    Text("3/5")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("done")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(teal)
                                }
                                .opacity(cardReady ? 1 : 0)
                                .animation(.easeOut.delay(0.4), value: cardReady)
                            }
                            
                            // Streak pill
                            VStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                    .scaleEffect(cardReady ? 1 : 0.6)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.5), value: cardReady)
                                Text("12")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("day streak")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .opacity(cardReady ? 1 : 0)
                            .animation(.easeOut.delay(0.55), value: cardReady)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(15)
                    
                }
            }
        }
        private func taskRow(_ title: String, done: Bool, idx: Int) -> some View {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? teal : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                    if done {
                        Circle().fill(teal).frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(Color(hex: "#0C0D16"))
                    }
                }
                .scaleEffect(cardReady && done ? 1 : (done ? 0.4 : 1))
                .animation(.spring(response: 0.35, dampingFraction: 0.55).delay(Double(idx) * 0.07 + 0.2), value: cardReady)
                
                Text(title)
                    .font(.system(size: 11, weight: done ? .regular : .medium))
                    .foregroundColor(done ? .white.opacity(0.3) : .white.opacity(0.8))
                    .strikethrough(done, color: .white.opacity(0.25))
            }
            .padding(.vertical, 7)
            .opacity(cardReady ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(Double(idx) * 0.06 + 0.15), value: cardReady)
        }
    }
    
    // MARK: - Page 2: AI Insights
    
    private struct Page2Card: View {
        let teal: Color
        let violet: Color
        let ink: Color
        let cardReady: Bool
        let isActive: Bool
        
        private let insights = [
            ("You skip Fridays 80% of the time", "flame.fill",       "#FF6B35"),
            ("Mornings beat evenings by 2×",      "sun.max.fill",    "#FFD60A"),
            ("Workout streak: personal best!",    "trophy.fill",     "#3ECFFF")
        ]
        
        private let stats: [(String, String, String)] = [
            ("B+", "Grade",  "#3ECFFF"),
            ("78%", "Weekly", "#7C6FFF"),
            ("12d", "Streak", "#FF6B35")
        ]
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(hex: "#13141F").opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [violet.opacity(0.28), teal.opacity(0.18), Color.white.opacity(0.06)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // AI label
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(violet)
                        Text("AI COACH INSIGHTS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(violet.opacity(0.8))
                    }
                    .padding(.bottom, 14)
                    
                    // Insight rows
                    VStack(spacing: 7) {
                        ForEach(Array(insights.enumerated()), id: \.offset) { idx, item in
                            insightRow(item.0, icon: item.1, color: Color(hex: item.2), delay: idx)
                        }
                    }
                    .padding(.bottom, 14)
                    
                    // Stats row
                    HStack(spacing: 8) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { idx, stat in
                            statPill(value: stat.0, label: stat.1, color: Color(hex: stat.2), delay: idx)
                        }
                    }
                }
                .padding(15)
            }
        }
        
        private func insightRow(_ text: String, icon: String, color: Color, delay: Int) -> some View {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                }
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                    )
            )
            .opacity(cardReady ? 1 : 0)
            .offset(y: cardReady ? 0 : 14)
            .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(Double(delay) * 0.09 + 0.15), value: cardReady)
        }
        
        private func statPill(value: String, label: String, color: Color, delay: Int) -> some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(color.opacity(0.18), lineWidth: 0.5)
                    )
            )
            .opacity(cardReady ? 1 : 0)
            .scaleEffect(cardReady ? 1 : 0.75)
            .animation(.spring(response: 0.4, dampingFraction: 0.65).delay(Double(delay) * 0.1 + 0.4), value: cardReady)
        }
    }
}

// MARK: - Preview
// ⚠️ Must live OUTSIDE the struct to avoid circular macro expansion

#Preview {
    OnboardingShowcaseView(onDismiss: {})
        .environmentObject(AppViewModel())
}
