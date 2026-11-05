package com.sortyd.app.data

import com.sortyd.app.data.model.DailySnapshot
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.localization.SortydStrings
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Serializable
data class StarterList(
    val emoji: String,
    val listName: String,
    val tasks: List<String>,
    val _dummy: Boolean = false
)

@Serializable
data class ParsedTask(
    val title: String,
    val reminderTime: String? = null,
    val isOneTime: Boolean = false,
    val healthType: String? = null,
    val healthTarget: Double? = null
)

@Serializable
data class AnalysisPillar(
    val name: String,
    val score: Int,
    val status: String,
    val emoji: String,
    val advice: List<String> = emptyList(),
    val relatedTasks: List<String> = emptyList(),
)

@Serializable
data class AnalysisResult(
    val grade: String,
    val headline: String,
    val reason: String,
    val pillars: List<AnalysisPillar> = emptyList(),
    val overallInsight: String = "",
    val skippedTasks: List<String> = emptyList(),
)

@Serializable
private data class AIMessage(val role: String, val content: String)

@Serializable
private data class AIRequest(
    val model: String,
    val messages: List<AIMessage>,
    val max_tokens: Int,
    val temperature: Double,
    val reasoning_effort: String = "low",
    val reasoning_format: String = "hidden",
)

object AICoach {
    // The Worker selects the Cloudflare model. This label keeps requests
    // compatible with the existing proxy contract and edge filtering.
    private const val MODEL = "llama3.1-8b"
    private const val API_URL = "https://api.sortyd.com/api/ai"
    private const val MAX_RESPONSE_BYTES = 128_000

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun generateStarterList(goal: String, language: String = "English"): Pair<StarterList?, String?> = withContext(Dispatchers.IO) {
        val langNote = "IMPORTANT: You MUST respond in $language. The listName and every task in the tasks array must be in fluent $language."
        
        val prompt = """
            You are a world-class habit coach helping someone build their first task list in Sortyd.
            Their goal: "$goal"
            $langNote

            YOUR JOB: Generate a complete, well-structured daily habit list that covers ALL dimensions of this goal.

            TASK COUNT RULES — this is critical:
            - ALWAYS generate between 4 and 6 tasks. Never fewer than 4. Never more than 6.
            - If the goal is broad, find distinct daily actions that build that lifestyle.
            - If the goal is narrow, expand it into supporting habits (hydration, sleep, prep).
            - Think in SYSTEMS, not single tasks.

            TASK QUALITY RULES:
            - Each task must be concrete and trackable.
            - Keep tasks short: 3–6 words in $language. Capitalize appropriately for the language.

            HEALTH TASK INTEGRATION — extremely important:
            - If the goal involves fitness, weight, gym, cardio, running, health, or activity, you MUST include:
              1. ONE steps task (e.g., "10,000 steps").
              2. ONE calories task (e.g., "Burn 500 kcal").
              3. ONE running/distance task (e.g., "Run 5km").
            - For these 3 tasks, you MUST shuffle/randomize the numeric targets slightly around these baselines:
              - Steps: baseline 10,000 (randomize between 6,000 and 12,000).
              - Calories: baseline 500 (randomize between 300 and 700).
              - Distance: baseline 5 (randomize between 3 and 10).

            CRITICAL — listName rules:
            - Return ONLY the core 1–3 word name. No emojis.
            - NEVER append filler words (System, Routine, Habits, etc.).

            Respond ONLY with valid JSON:
            {
              "emoji": "single relevant emoji",
              "listName": "1–3 words, core goal only, in $language, NO filler suffixes",
              "tasks": ["Task 1 in $language", "Task 2", "Task 3", "Task 4", "Task 5"]
            }
        """.trimIndent()

        when (val result = post(prompt, maxTokens = 700, temperature = 0.7)) {
            is Result.Success -> {
                val responseText = result.value
                val extractedJson = extractJsonFromResponse(responseText)
                if (extractedJson != null) {
                    try {
                        return@withContext Pair(json.decodeFromString<StarterList>(extractedJson), null)
                    } catch (e: Exception) {
                        return@withContext Pair(null, "JSON Parse Error: ${e.message}\nJSON: $extractedJson")
                    }
                } else {
                    return@withContext Pair(null, "Failed to extract JSON from response. Raw: $responseText")
                }
            }
            is Result.Failure -> {
                return@withContext Pair(null, result.message)
            }
        }
    }

    suspend fun generateBehaviouralAnalysis(
        tasks: List<SortydTask>,
        snapshots: List<DailySnapshot>,
        listName: String,
        languageCode: String = "en",
    ): AnalysisResult? = withContext(Dispatchers.IO) {
        val language = SortydStrings.languageName(languageCode)
        val statusValues = SortydStrings.statusValues(languageCode)
        val oneDayMs = 24 * 60 * 60 * 1000L
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0); set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
        }
        val todayMs = cal.timeInMillis
        val recent = snapshots.filter { it.date >= todayMs - 30 * oneDayMs }.sortedBy { it.date }
        val overallAvg = if (recent.isEmpty()) 0 else (recent.map { it.completionFraction }.average() * 100).toInt()
        val completionSummary = if (recent.isEmpty()) "No data yet." else recent.takeLast(14).joinToString(", ") { "${(it.completionFraction * 100).toInt()}%" }
        val taskNames = tasks.take(10).joinToString(", ") { it.title.replace("\"", "'") }

        val prompt = "You are Sortyd's AI behavioural coach. You MUST respond in $language. Every JSON text value must be fluent $language. For pillar status, use ONLY one of: $statusValues. Do not use English status words unless language is English. List: \\\"$listName\\\". Tasks: $taskNames. Last 14-day completions: $completionSummary. Overall avg: $overallAvg%. Analyse and respond ONLY with this JSON: {\\\"grade\\\":\\\"A/B/C/D\\\",\\\"headline\\\":\\\"2-5 words in $language\\\",\\\"reason\\\":\\\"1 sentence in $language\\\",\\\"pillars\\\":[{\\\"name\\\":\\\"Pillar name in $language\\\",\\\"score\\\":70,\\\"status\\\":\\\"One of: $statusValues\\\",\\\"emoji\\\":\\\"🔄\\\",\\\"advice\\\":[\\\"tip1 in $language\\\",\\\"tip2 in $language\\\"],\\\"relatedTasks\\\":[]},{\\\"name\\\":\\\"Pillar name in $language\\\",\\\"score\\\":60,\\\"status\\\":\\\"One of: $statusValues\\\",\\\"emoji\\\":\\\"⚡\\\",\\\"advice\\\":[\\\"tip in $language\\\"],\\\"relatedTasks\\\":[]},{\\\"name\\\":\\\"Pillar name in $language\\\",\\\"score\\\":80,\\\"status\\\":\\\"One of: $statusValues\\\",\\\"emoji\\\":\\\"🎯\\\",\\\"advice\\\":[\\\"tip in $language\\\"],\\\"relatedTasks\\\":[]}],\\\"overallInsight\\\":\\\"2-3 sentences in $language\\\",\\\"skippedTasks\\\":[]}"

        when (val result = post(prompt, maxTokens = 900, temperature = 0.4)) {
            is Result.Success -> {
                val responseText = result.value
                val extractedJson = extractJsonFromResponse(responseText)
                if (extractedJson != null) {
                    val decoded = runCatching { json.decodeFromString<AnalysisResult>(extractedJson) }.getOrNull()
                    if (decoded != null && decoded.pillars.isNotEmpty()) {
                        return@withContext decoded
                    }
                }
            }
            is Result.Failure -> Unit
        }
        buildFallbackAnalysis(tasks, snapshots, listName, overallAvg)
    }

    private fun buildFallbackAnalysis(
        tasks: List<SortydTask>,
        snapshots: List<DailySnapshot>,
        listName: String,
        overallAvg: Int
    ): AnalysisResult {
        val cleanName = listName.trim().ifEmpty { "Daily Routine" }
        val completedToday = tasks.count { it.isCompleted }
        val effectiveScore = if (snapshots.isNotEmpty()) overallAvg.coerceIn(35, 100)
        else if (tasks.isNotEmpty()) ((completedToday.toDouble() / tasks.size) * 100).toInt().coerceIn(45, 100)
        else 75

        val grade = when {
            effectiveScore >= 90 -> "A"
            effectiveScore >= 82 -> "A-"
            effectiveScore >= 75 -> "B+"
            effectiveScore >= 66 -> "B"
            effectiveScore >= 58 -> "B-"
            else -> "C+"
        }

        val taskTitles = tasks.map { it.title }.ifEmpty { listOf(cleanName) }
        val mid = ((taskTitles.size + 1) / 2).coerceAtLeast(1)
        val firstHalf = taskTitles.take(mid)
        val secondHalf = taskTitles.drop(mid)
        val skipped = tasks.filter { !it.isCompleted }.map { it.title }.take(3)

        val p1Score = (effectiveScore + 5).coerceIn(0, 100)
        val p2Score = (effectiveScore - 6).coerceIn(0, 100)

        val pillars = buildList {
            add(
                AnalysisPillar(
                    name = "$cleanName Core",
                    score = p1Score,
                    status = if (p1Score >= 70) "Strong" else if (p1Score >= 45) "Developing" else "Needs Work",
                    emoji = "🎯",
                    advice = listOf(
                        "Complete \"${firstHalf.first()}\" at the same time every day to anchor your streak.",
                        "Prepare your environment the evening before to remove starting friction."
                    ),
                    relatedTasks = firstHalf
                )
            )
            if (secondHalf.isNotEmpty()) {
                add(
                    AnalysisPillar(
                        name = "Follow-Through & Cadence",
                        score = p2Score,
                        status = if (p2Score >= 70) "Strong" else if (p2Score >= 45) "Developing" else "Needs Work",
                        emoji = "⚡",
                        advice = listOf(
                            "Stack \"${secondHalf.first()}\" immediately after \"${firstHalf.first()}\" so there is zero pause between habits."
                        ),
                        relatedTasks = secondHalf
                    )
                )
            }
        }

        return AnalysisResult(
            grade = grade,
            headline = "$cleanName holding at $effectiveScore% consistency",
            reason = "Averaging $effectiveScore% across ${tasks.size.coerceAtLeast(1)} habits, anchored by \"${firstHalf.first()}\".",
            pillars = pillars,
            overallInsight = "Your \"$cleanName\" list is running at $effectiveScore% consistency. Pairing \"${secondHalf.firstOrNull() ?: firstHalf.last()}\" directly after \"${firstHalf.first()}\" will close your remaining daily gap.",
            skippedTasks = skipped
        )
    }

    suspend fun parseNaturalLanguageTask(input: String): ParsedTask? = withContext(Dispatchers.IO) {
        val prompt = """
            You are a smart task parser. Extract the title and reminder from this input.
            Input: "$input"

            RULES:
            1. Title should be concise and clean.
            2. Extract time only if specified (e.g., "at 5pm", "8:30 in the morning").
            3. Use 24-hour format for reminderTime (e.g., "17:00", "08:30").
            4. If it's a health task (steps, calories, distance, screentime), specify healthType and healthTarget.
               - Types: "steps", "calories", "distance", "screentime"
            5. If it sounds like a one-time event, set isOneTime to true.

            Respond ONLY with valid JSON:
            {
              "title": "Clean task title",
              "reminderTime": "HH:mm or null",
              "isOneTime": true/false,
              "healthType": "steps/calories/distance or null",
              "healthTarget": 1234.5 or null
            }
        """.trimIndent()

        when (val result = post(prompt, maxTokens = 300, temperature = 0.1)) {
            is Result.Success -> {
                val responseText = result.value
                val extractedJson = extractJsonFromResponse(responseText)
                if (extractedJson != null) {
                    return@withContext runCatching { json.decodeFromString<ParsedTask>(extractedJson) }.getOrNull()
                }
            }
            is Result.Failure -> Unit
        }
        null
    }

    private fun post(prompt: String, maxTokens: Int, temperature: Double): Result {
        val requestBody = json.encodeToString(
            AIRequest(MODEL, listOf(AIMessage("user", prompt)), maxTokens, temperature)
        )
        val connection = (URL(API_URL).openConnection() as HttpURLConnection)
        return try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = 10_000
            connection.readTimeout = 30_000
            connection.setFixedLengthStreamingMode(requestBody.toByteArray(Charsets.UTF_8).size)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "Sortyd/1.0 (Android)")
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(requestBody) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText().take(MAX_RESPONSE_BYTES) }.orEmpty()
            if (code == HttpURLConnection.HTTP_OK) Result.Success(body)
            else Result.Failure("AI request failed ($code)")
        } catch (_: Exception) {
            Result.Failure("AI request could not be completed")
        } finally {
            connection.disconnect()
        }
    }

    private sealed interface Result {
        data class Success(val value: String) : Result
        data class Failure(val message: String) : Result
    }

    private fun extractJsonFromResponse(response: String): String? {
        try {
            val jsonObject = org.json.JSONObject(response)
            val choices = jsonObject.optJSONArray("choices")
            if (choices != null && choices.length() > 0) {
                val message = choices.getJSONObject(0).optJSONObject("message")
                if (message != null) {
                    val content = message.optString("content", "")
                    val start = content.indexOf('{')
                    val end = content.lastIndexOf('}')
                    if (start != -1 && end != -1) {
                        return content.substring(start, end + 1)
                    }
                }
            }
        } catch (e: Exception) {
            // silently ignore — AI features degrade gracefully on network failure
        }
        return null
    }
}
