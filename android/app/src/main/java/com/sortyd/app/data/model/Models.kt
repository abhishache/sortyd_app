package com.sortyd.app.data.model

/** Health task types matching iOS HealthTaskType */
enum class HealthTaskType(val rawValue: String, val displayName: String, val unit: String) {
    STEPS("steps", "Steps", "steps"),
    CALORIES("calories", "Calories", "kcal"),
    DISTANCE("distance", "Distance", "km"),
    SCREEN_TIME("screentime", "Screen Time", "hrs");

    companion object {
        /**
         * Keyword-based detection — mirrors iOS HealthKitManager.swift HealthTaskType.detect(from:)
         * Priority: exclusions → high-confidence phrases → base keyword whole-word matching.
         */
        fun detect(from: String): HealthTaskType? {
            val lower = from.lowercase()

            // 1. Exclusions — if these exist, it is NOT a health task
            val exclusions = listOf(
                "energy drink", "energy bill", "energy level", "energy bar",
                "step by step", "next step", "step up", "step down",
                "walk through", "walk in", "sidewalk", "cake walk",
                "burn out", "burn down", "burnish", "sideburn",
                "job", "career", "guitar", "instrument", "lesson", "piano", "study",
                "at work", "work meeting", "work task", "work project", "work shift"
            )
            if (exclusions.any { lower.contains(it) }) return null

            // 2. High-confidence phrases (English, Arabic, Spanish)
            val stepPhrases = listOf(
                "10k steps", "10,000 steps", "hit 10k", "pedometer", "daily steps", "steps today",
                "١٠ آلاف خطوة", "خطوات اليوم", "10k pasos", "pasos diarios"
            )
            val calPhrases = listOf(
                "active energy", "cal burned", "calories burned", "fat burn", "weight loss", "calorie deficit",
                "سعرات محروقة", "حرق دهون", "calorías quemadas", "déficit calórico"
            )
            val distPhrases = listOf(
                "run 5km", "run 10km", "5km run", "10km run", "track distance", "jog 5k",
                "جري ٥ كم", "مسافة اليوم", "correr 5km", "distancia diaria"
            )
            val screenPhrases = listOf(
                "screen time", "phone usage", "app limit", "tiempo en pantalla", "uso del teléfono", "وقت الشاشة", "استخدام الهاتف"
            )
            if (stepPhrases.any { lower.contains(it) }) return STEPS
            if (calPhrases.any  { lower.contains(it) }) return CALORIES
            if (distPhrases.any { lower.contains(it) }) return DISTANCE
            if (screenPhrases.any { lower.contains(it) }) return SCREEN_TIME

            // 3. Base keywords checked as whole words
            val stepWordsEn  = setOf("steps", "walk", "walking", "pedometer")
            val calWordsEn   = setOf("calorie", "calories", "kcal", "burn", "burned",
                "activity", "hike", "hiking", "cardio", "fitness", "workout",
                "gym", "exercise", "training", "sport")
            val distWordsEn  = setOf("run", "running", "jog", "jogging", "km", "kms",
                "kilometer", "kilometers", "distance", "mile", "miles")

            val stepWordsAr  = setOf("خطوة", "خطوات", "مشي")
            val calWordsAr   = setOf("سعرة", "سعرات", "حرارية", "حرق", "نشاط",
                "تمارين", "تمرين", "رياضة", "لياقة", "جم", "تدريب", "كارديو", "جيم")
            val distWordsAr  = setOf("جري", "ركض", "كم", "كيلومتر", "مسافة")

            val stepWordsEs  = setOf("pasos", "caminar", "andar")
            val calWordsEs   = setOf("caloría", "calorías", "caloria", "calorias", "quemar",
                "quemado", "activo", "entrenamiento", "ejercicio", "gimnasio",
                "deporte", "actividad", "fitness", "cardio", "gym")
            val distWordsEs  = setOf("correr", "trote", "distancia", "km", "kms",
                "kilómetro", "kilómetros")

            val screenWordsEn = setOf("screen", "phone", "screentime")
            val screenWordsAr = setOf("شاشة", "هاتف", "جوال")
            val screenWordsEs = setOf("pantalla", "teléfono", "celular")

            val words = lower.split(Regex("[^a-zA-Z0-9\u0600-\u06FF]+")).filter { it.isNotEmpty() }.toSet()

            // Distance has highest priority (overlaps with calorie words like "run")
            if (words.any { it in distWordsEn || it in distWordsAr || it in distWordsEs }) return DISTANCE
            if (words.any { it in screenWordsEn || it in screenWordsAr || it in screenWordsEs }) return SCREEN_TIME
            if (words.any { it in stepWordsEn || it in stepWordsAr || it in stepWordsEs }) return STEPS
            if (words.any { it in calWordsEn  || it in calWordsAr  || it in calWordsEs  }) return CALORIES

            return null
        }

        /** Default target values for each health type, matching iOS baselines. */
        fun defaultTarget(type: HealthTaskType): Double = when (type) {
            STEPS    -> 10_000.0
            CALORIES -> 500.0
            DISTANCE -> 5.0
            SCREEN_TIME -> 2.0
        }

        fun fromRawValue(raw: String?): HealthTaskType? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** Data class for today's health readings */
data class HealthSnapshot(
    val steps: Double = 0.0,
    val calories: Double = 0.0,
    val distanceKm: Double = 0.0,
    val screenTime: Double = 0.0, // Hours
)

/** Undo/redo action types for task operations */
sealed class UndoAction {
    data class ToggleTask(val taskId: String, val listId: String, val wasCompleted: Boolean) : UndoAction()
    data class AddTask(val task: SortydTask) : UndoAction()
    data class DeleteTask(val task: SortydTask, val index: Int) : UndoAction()
    data class ReorderTasks(val listId: String, val previousOrder: List<String>) : UndoAction()
    data class EditTask(val previousTask: SortydTask) : UndoAction()
}

/** Performance recap data for the daily notification */
data class DailyRecapData(
    val percentage: Int,
    val message: String,
    val emoji: String,
    val listName: String,
    val dateLabel: String
)

/** App language matching iOS AppLanguage */
enum class AppLanguage(val code: String, val displayName: String, val isRtl: Boolean = false) {
    ENGLISH("en", "English"),
    SPANISH("es", "Español"),
    ARABIC("ar", "العربية", isRtl = true),
    CHINESE("zh-Hans", "中文"),
}
