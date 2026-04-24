// MARK: - HealthKitManager.swift
// Sortyd — HealthKit integration for steps and calories tasks
// Permission is requested lazily — only when a health task is detected, never on app launch.

import Foundation
import HealthKit
import Combine

// MARK: - Health task type detection

enum HealthTaskType: String, Codable {
    case steps
    case calories
    case distance
    case none

    /// Keyword-based detection from task title
    static func detect(from title: String) -> HealthTaskType {
        let lower = title.lowercased()

        // 1. Exclusions (Higher priority — if these exist, it's NOT a health task)
        let exclusions = [
            "energy drink", "energy bill", "energy level", "energy bar",
            "step by step", "next step", "step up", "step down",
            "walk through", "walk in", "sidewalk", "cake walk",
            "burn out", "burn down", "burnish", "sideburn",
            "job", "career", "guitar", "instrument", "lesson", "piano", "study", "work" 
        ]
        if exclusions.contains(where: { lower.contains($0) }) { return .none }

        // 2. High-confidence phrases (English, Arabic, Spanish)
        let stepPhrases = [
            "10k steps", "10,000 steps", "hit 10k", "pedometer", "daily steps", "steps today",
            "١٠ آلاف خطوة", "خطوات اليوم", "10k pasos", "pasos diarios"
        ]
        let calPhrases  = [
            "active energy", "cal burned", "calories burned", "fat burn", "weight loss", "calorie deficit",
            "سعرات محروقة", "حرق دهون", "calorías quemadas", "déficit calórico"
        ]
        let distPhrases = [
            "run 5km", "run 10km", "5km run", "10km run", "track distance", "jog 5k",
            "جري ٥ كم", "مسافة اليوم", "correr 5km", "distancia diaria"
        ]

        if stepPhrases.contains(where: { lower.contains($0) }) { return .steps }
        if calPhrases.contains(where: { lower.contains($0) }) { return .calories }
        if distPhrases.contains(where: { lower.contains($0) }) { return .distance }

        // 3. Base keywords (checked as whole words)
        // English
        let stepWordsEn: Set<String> = ["steps", "walk", "walking", "pedometer"]
        let calWordsEn:  Set<String> = ["calorie", "calories", "kcal", "burn", "burned", "activity", "hike", "hiking", "cardio", "fitness", "workout", "gym", "exercise", "training", "sport"]
        let distWordsEn: Set<String> = ["run", "running", "jog", "jogging", "km", "kms", "kilometer", "kilometers", "distance", "mile", "miles"]
        
        // Arabic
        let stepWordsAr: Set<String> = ["خطوة", "خطوات", "مشي"]
        let calWordsAr:  Set<String> = ["سعرة", "سعرات", "حرارية", "حرق", "نشاط", "تمارين", "تمرين", "رياضة", "لياقة", "جم", "تدريب", "كارديو", "جيم"]
        let distWordsAr: Set<String> = ["جري", "ركض", "كم", "كيلومتر", "مسافة"]
        
        // Spanish
        let stepWordsEs: Set<String> = ["pasos", "caminar", "andar"]
        let calWordsEs:  Set<String> = ["caloría", "calorías", "caloria", "calorias", "quemar", "quemado", "activo", "entrenamiento", "ejercicio", "gimnasio", "deporte", "actividad", "fitness", "cardio", "gym"]
        let distWordsEs: Set<String> = ["correr", "trote", "distancia", "km", "kms", "kilómetro", "kilómetros"]

        // 3. Base keywords (checked as whole words)
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if words.contains(where: { distWordsEn.contains($0) || distWordsAr.contains($0) || distWordsEs.contains($0) }) { return .distance }
        if words.contains(where: { stepWordsEn.contains($0) || stepWordsAr.contains($0) || stepWordsEs.contains($0) }) { return .steps }
        if words.contains(where: { calWordsEn.contains($0) || calWordsAr.contains($0) || calWordsEs.contains($0) })  { return .calories }

        return .none
    }

    var quantityType: HKQuantityType? {
        switch self {
        case .steps:    return HKQuantityType(.stepCount)
        case .calories: return HKQuantityType(.activeEnergyBurned)
        case .distance: return HKQuantityType(.distanceWalkingRunning)
        case .none:     return nil
        }
    }

    var unit: HKUnit {
        switch self {
        case .steps:    return .count()
        case .calories: return .kilocalorie()
        case .distance: return .meterUnit(with: .kilo)
        case .none:     return .count()
        }
    }

    var icon: String {
        switch self {
        case .steps:    return "figure.walk"
        case .calories: return "flame.fill"
        case .distance: return "figure.run"
        case .none:     return "checkmark"
        }
    }

    var label: String {
        let langCode = (UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? .standard).string(forKey: "sortyd_app_language") ?? "en"
        let locale = Locale(identifier: langCode)
        switch self {
        case .steps:    return String(localized: "Steps", locale: locale)
        case .calories: return String(localized: "Cal", locale: locale)
        case .distance: return String(localized: "Km", locale: locale)
        case .none:     return ""
        }
    }

    var accentColor: String {
        switch self {
        case .steps:    return "#4FC3F7"
        case .calories: return "#FF7043"
        case .distance: return "#2E7D32" // Darker Green for Distance/Run
        case .none:     return "#FFC107"
        }
    }

    var placeholder: String {
        let langCode = (UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? .standard).string(forKey: "sortyd_app_language") ?? "en"
        let locale = Locale(identifier: langCode)
        switch self {
        case .steps:    return String(localized: "e.g. 10000", locale: locale)
        case .calories: return String(localized: "e.g. 500", locale: locale)
        case .distance: return String(localized: "e.g. 5", locale: locale)
        case .none:     return ""
        }
    }
}

// MARK: - HealthKitManager

@MainActor
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var todaySteps: Double    = 0
    @Published private(set) var todayCalories: Double = 0
    @Published private(set) var todayDistance: Double = 0

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?
    private var observerQueries: [HKObserverQuery] = []
    private var anchoredQueries: [HKAnchoredObjectQuery] = []

    // AppViewModel sets this closure to auto-tick health tasks when target is hit
    var onHealthUpdate: ((_ steps: Double, _ calories: Double, _ distance: Double) -> Void)?

    // Persists whether the user has ever granted HealthKit read access.
    // iOS never returns .sharingAuthorized for read-only apps (intentional privacy
    // design), so we track grant state ourselves to avoid re-prompting every launch.
    private let hkDefaults = UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? UserDefaults.standard
    private let hkGrantedKey = "hk_permission_granted"

    private init() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // If the user previously granted access, resume live tracking immediately
        // without calling requestAuthorization (which would show the sheet again).
        if hkDefaults.bool(forKey: hkGrantedKey) {
            isAuthorized = true
            fetchToday()
            startLiveUpdates()
        }
        // If not yet granted, permission is requested lazily when the user
        // adds a health task (HealthPermissionSheet). After granting,
        // requestPermission() saves the flag, then calls fetchToday() + startLiveUpdates().
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hkDefaults.set(true, forKey: hkGrantedKey)
            isAuthorized = true
            fetchToday()
            startLiveUpdates()
            return true
        } catch {
            return false
        }
    }

    // MARK: - One-shot fetch (start of day to now)

    func fetchToday() {
        refreshTask?.cancel()
        refreshTask = Task {
            async let steps    = fetchSum(type: HKQuantityType(.stepCount), unit: .count())
            async let calories = fetchSum(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
            async let distance = fetchSum(type: HKQuantityType(.distanceWalkingRunning), unit: .meterUnit(with: .kilo))
            let (s, c, d) = await (steps, calories, distance)
            guard !Task.isCancelled else { return }
            todaySteps    = s
            todayCalories = c
            todayDistance = d
            onHealthUpdate?(s, c, d)
        }
    }

    // MARK: - Real-time live updates
    // HKAnchoredObjectQuery fires every time a new HealthKit sample arrives.
    // HKObserverQuery + enableBackgroundDelivery handles wakeup when backgrounded.

    func startLiveUpdates() {
        stopLiveUpdates()

        let types: [(HKQuantityType, HKUnit)] = [
            (HKQuantityType(.stepCount),              .count()),
            (HKQuantityType(.activeEnergyBurned),     .kilocalorie()),
            (HKQuantityType(.distanceWalkingRunning), .meterUnit(with: .kilo))
        ]

        for (quantityType, _) in types {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let predicate  = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: nil,
                options: .strictStartDate
            )

            // Anchored query — fires immediately with existing samples,
            // then updateHandler fires on every new sample added.
            let anchored = HKAnchoredObjectQuery(
                type: quantityType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, _, _, _, _ in
                Task { @MainActor [weak self] in self?.fetchToday() }
            }
            anchored.updateHandler = { [weak self] _, _, _, _, _ in
                Task { @MainActor [weak self] in self?.fetchToday() }
            }
            store.execute(anchored)
            anchoredQueries.append(anchored)

            // Observer query — needed for background delivery
            let observer = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor [weak self] in self?.fetchToday() }
                completion() // must call or HealthKit throttles future deliveries
            }
            store.execute(observer)
            observerQueries.append(observer)

            // Enable background delivery at .immediate frequency
            store.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { _, _ in }
        }
    }

    private func stopLiveUpdates() {
        anchoredQueries.forEach { store.stop($0) }
        observerQueries.forEach { store.stop($0) }
        anchoredQueries.removeAll()
        observerQueries.removeAll()
    }

    // MARK: - Core sum fetch

    private func fetchSum(type: HKQuantityType, unit: HKUnit) async -> Double {
        let now        = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate  = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    // MARK: - Progress helpers

    func progress(for type: HealthTaskType, target: Double) -> Double {
        guard target > 0 else { return 0 }
        switch type {
        case .steps:    return min(todaySteps    / target, 1.0)
        case .calories: return min(todayCalories / target, 1.0)
        case .distance: return min(todayDistance / target, 1.0)
        case .none:     return 0
        }
    }

    func currentValue(for type: HealthTaskType) -> Double {
        switch type {
        case .steps:    return todaySteps
        case .calories: return todayCalories
        case .distance: return todayDistance
        case .none:     return 0
        }
    }

    func healthValues(for tasks: [SortydTask]) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for task in tasks {
            guard task.isHealthTask,
                  let htStr  = task.healthType,
                  let ht     = HealthTaskType(rawValue: htStr),
                  let target = task.healthTarget else { continue }
            result[task.id] = progress(for: ht, target: target)
        }
        return result
    }
}
