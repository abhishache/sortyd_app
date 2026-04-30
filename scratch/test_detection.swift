
import Foundation

enum HealthTaskType: String {
    case steps
    case calories
    case distance
    case none

    static func detect(from title: String) -> HealthTaskType {
        let lower = title.lowercased()

        // 1. Exclusions
        let exclusions = [
            "energy drink", "energy bill", "energy level", "energy bar",
            "step by step", "next step", "step up", "step down",
            "walk through", "walk in", "sidewalk", "cake walk"
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
        let stepWordsEn: Set<String> = ["steps", "walk", "walking", "pedometer"]
        let calWordsEn:  Set<String> = ["calorie", "calories", "kcal", "burn", "burned", "activity", "hike", "hiking", "cardio", "fitness", "workout", "gym", "exercise", "training", "sport"]
        let distWordsEn: Set<String> = ["run", "running", "jog", "jogging", "km", "kms", "kilometer", "kilometers", "distance", "mile", "miles"]
        
        let stepWordsAr: Set<String> = ["خطوة", "خطوات", "مشي"]
        let calWordsAr:  Set<String> = ["سعرة", "سعرات", "حرارية", "حرق", "نشاط", "تمارين", "تمرين", "رياضة", "لياقة", "جم", "تدريب", "كارديو", "جيم"]
        let distWordsAr: Set<String> = ["جري", "ركض", "كم", "كيلومتر", "مسافة"]
        
        let stepWordsEs: Set<String> = ["pasos", "caminar", "andando", "andante"]
        let calWordsEs:  Set<String> = ["caloría", "calorías", "kcal", "quemar", "quemadas", "actividad", "senderismo", "gimnasio", "ejercicio", "entrenamiento", "deporte"]
        let distWordsEs: Set<String> = ["correr", "corriendo", "trote", "trotar", "km", "kms", "kilómetro", "kilómetros", "distancia", "milla", "millas"]

        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        
        for word in words {
            // Distance check first (priority for running)
            if distWordsEn.contains(word) || distWordsAr.contains(word) || distWordsEs.contains(word) { return .distance }
            if calWordsEn.contains(word) || calWordsAr.contains(word) || calWordsEs.contains(word) { return .calories }
            if stepWordsEn.contains(word) || stepWordsAr.contains(word) || stepWordsEs.contains(word) { return .steps }
        }

        return .none
    }
}

let testCases: [(String, HealthTaskType)] = [
    // English
    ("Run 5km daily", .distance),
    ("Go for a 10km run", .distance),
    ("Morning jogging", .distance),
    ("Track my distance today", .distance),
    ("Walk 10,000 steps", .steps),
    ("Burn 500 calories", .calories),
    ("Fat burn workout", .calories),
    ("Buy an energy drink", .none), // Exclusion
    ("Next step in project", .none), // Exclusion
    
    // Arabic
    ("جري ٥ كم كل صباح", .distance),
    ("مسافة اليوم", .distance),
    ("مشي ١٠ آلاف خطوة", .steps),
    ("حرق سعرات حرارية", .calories),
    ("تمارين رياضية", .calories),
    
    // Spanish
    ("Correr 5km", .distance),
    ("Distancia diaria de trote", .distance),
    ("Caminar 10000 pasos", .steps),
    ("Quemar calorías hoy", .calories),
    ("Entrenamiento de gimnasio", .calories)
]

print("Testing HealthTaskType.detect...\n")
var passedCount = 0
for (title, expected) in testCases {
    let result = HealthTaskType.detect(from: title)
    let status = result == expected ? "✅ PASS" : "❌ FAIL"
    if result == expected { passedCount += 1 }
    print("\(status) [\(expected.rawValue.uppercased())] -> \"\(title)\" (Detected: \(result.rawValue))")
}

print("\nResults: \(passedCount)/\(testCases.count) tests passed.")
if passedCount == testCases.count {
    print("All distance and health detection logic is working correctly!")
}
