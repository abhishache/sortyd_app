package com.sortyd.app.ai

import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.sortyd.app.model.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

@Singleton
class AICoach @Inject constructor() {
    private val TAG = "AICoach"
    private val gson = Gson()
    private val client = OkHttpClient()

    private val proxyUrl = "https://sortyd-proxy.abhishek918.workers.dev/api/ai"
    private val hmacSalt = "com.sortyd.sortyd|Sortyd|v1"

    // ── HMAC Auth ─────────────────────────────────────────────────────────────

    private fun buildSignedRequest(body: String): Request {
        val timestamp = System.currentTimeMillis() / 1000
        val message = "$timestamp.$body"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(hmacSalt.toByteArray(), "HmacSHA256"))
        val sig = mac.doFinal(message.toByteArray()).joinToString("") { "%02x".format(it) }

        return Request.Builder()
            .url(proxyUrl)
            .post(body.toRequestBody("application/json".toMediaType()))
            .header("x-sortyd-ts", timestamp.toString())
            .header("x-sortyd-sig", sig)
            .header("Content-Type", "application/json")
            .build()
    }

    private suspend fun call(combinedPrompt: String, maxTokens: Int = 1024): String =
        suspendCoroutine { cont ->
            val bodyJson = gson.toJson(mapOf(
                "model" to "llama3.1-8b",
                "messages" to listOf(
                    mapOf("role" to "user", "content" to combinedPrompt)
                ),
                "max_tokens" to maxTokens,
                "temperature" to 0.7
            ))

            client.newCall(buildSignedRequest(bodyJson)).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) =
                    cont.resumeWithException(e)

                override fun onResponse(call: Call, response: Response) {
                    val raw = response.body?.string() ?: "{}"
                    try {
                        val parsed = gson.fromJson(raw, AIResponse::class.java)
                        cont.resumeWith(Result.success(
                            parsed.choices?.firstOrNull()?.message?.content ?: ""
                        ))
                    } catch (e: Exception) {
                        cont.resumeWith(Result.success(""))
                    }
                }
            })
        }

    // ── Parse Natural Language Task ───────────────────────────────────────────

    suspend fun parseNaturalLanguageTask(input: String, language: AppLanguage): ParsedTask {
        val langInstruction = when (language) {
            AppLanguage.ARABIC -> "Respond in Arabic."
            AppLanguage.SPANISH -> "Respond in Spanish."
            else -> "Respond in English."
        }
        val prompt = """
            You are a task parser. Extract a clean task title and optional reminder time from user input.
            $langInstruction
            Return JSON only: {"title": "...", "hasReminder": true/false, "reminderHour": 14, "reminderMinute": 30}
            If no time found, set hasReminder to false and reminderHour/reminderMinute to null.

            Input: $input
        """.trimIndent()

        return try {
            val raw = call(prompt, maxTokens = 256)
            val json = extractJson(raw)
            val parsed = gson.fromJson(json, ParsedTaskJson::class.java)
            ParsedTask(
                title = parsed.title ?: input,
                hasReminder = parsed.hasReminder ?: false,
                reminderHour = parsed.reminderHour,
                reminderMinute = parsed.reminderMinute
            )
        } catch (e: Exception) {
            Log.e(TAG, "parseTask failed", e)
            ParsedTask(title = input, hasReminder = false, reminderHour = null, reminderMinute = null)
        }
    }

    // ── Generate Starter List ─────────────────────────────────────────────────

    suspend fun generateStarterList(goal: String, language: AppLanguage): StarterList {
        val langCode = language.code
        val bannedSuffixes = listOf(
            "system", "routine", "builder", "plan", "program", "tracker",
            "habit", "goals", "challenge", "نظام", "روتين", "منهج", "sistema", "rutina"
        )

        val prompt = """
            You are a habit coach. Generate a personalized habit list from a goal.
            Language: $langCode. Always respond in that language.
            Return ONLY valid JSON: {
              "emoji": "🏃",
              "listName": "Morning Focus",
              "tasks": [
                {"title": "Run 5km", "healthType": "distance", "healthTarget": 5.0},
                {"title": "Drink water", "healthType": null, "healthTarget": null}
              ]
            }
            Rules:
            - 4-6 tasks total
            - listName must be SHORT (2-3 words), NO suffixes like: ${bannedSuffixes.joinToString(", ")}
            - For fitness goals include steps/calories/distance tasks
            - healthType: "steps", "calories", "distance", or null

            Goal: $goal
        """.trimIndent()

        return try {
            val raw = call(prompt)
            val json = extractJson(raw)
            val parsed = gson.fromJson(json, StarterListJson::class.java)

            val cleanName = stripBannedSuffixes(parsed.listName ?: goal, bannedSuffixes)
            StarterList(
                emoji = parsed.emoji ?: "📋",
                listName = cleanName,
                tasks = (parsed.tasks ?: emptyList()).map {
                    StarterListTask(
                        title = it.title ?: "",
                        healthType = it.healthType ?: HealthTaskType.NONE.rawValue,
                        healthTarget = it.healthTarget
                    )
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "generateStarterList failed", e)
            StarterList(emoji = "📋", listName = goal, tasks = emptyList())
        }
    }

    // ── Weekly Recap ──────────────────────────────────────────────────────────

    suspend fun generateWeeklyRecap(
        lists: List<TaskList>,
        snapshots: List<DailySnapshot>,
        language: AppLanguage
    ): WeeklyRecap {
        val langCode = language.code
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val summary = lists.filter { !it.isArchived && !it.isTodo }.joinToString("\n") { list ->
            val listSnaps = snapshots.filter { it.listId == list.id }.takeLast(7)
            "List: ${list.name} | 7-day avg: ${listSnaps.map { it.completionFraction }.average().let { "%.0f%%".format(it * 100) }}"
        }

        val prompt = """
            You are an expert habit coach. Analyze the following habit data and generate a weekly recap.
            Language code: $langCode. Respond entirely in that language.
            Return ONLY JSON: {
              "headline": "...", "summary": "...", "highlight": "...",
              "nudge": "...", "grade": "B+", "gradeReason": "..."
            }

            Data:
            $summary
        """.trimIndent()

        return try {
            val raw = call(prompt)
            val json = extractJson(raw)
            val parsed = gson.fromJson(json, WeeklyRecapJson::class.java)
            WeeklyRecap(
                headline = parsed.headline ?: "",
                summary = parsed.summary ?: "",
                highlight = parsed.highlight ?: "",
                nudge = parsed.nudge ?: "",
                grade = parsed.grade ?: "B",
                gradeReason = parsed.gradeReason ?: ""
            )
        } catch (e: Exception) {
            Log.e(TAG, "weeklyRecap failed", e)
            WeeklyRecap("", "", "", "", "B", "")
        }
    }

    // ── Behavioural Analysis ──────────────────────────────────────────────────

    suspend fun analyseBehaviouralPillars(
        lists: List<TaskList>,
        snapshots: List<DailySnapshot>,
        language: AppLanguage
    ): BehaviouralAnalysis {
        val summary = lists.filter { !it.isArchived && !it.isTodo }.joinToString("\n") { list ->
            val listSnaps = snapshots.filter { it.listId == list.id }
            "List: ${list.name} | Tasks: ${list.tasks.joinToString(", ") { it.title }} | Avg: ${listSnaps.map { it.completionFraction }.average().let { "%.0f%%".format(it * 100) }}"
        }
        val prompt = """
            You are a behavioral analyst. Group the following habits into 2-4 pillars (Health, Discipline, Mindset, etc.).
            Language: ${language.code}. Respond in that language.
            Return ONLY JSON: {
              "pillars": [{"name":"...","score":80,"status":"Strong","tasks":["..."],"insight":"...","advice":"..."}],
              "overallInsight": "...",
              "criticalPillar": "..."
            }

            Data:
            $summary
        """.trimIndent()

        return try {
            val raw = call(prompt)
            val json = extractJson(raw)
            val parsed = gson.fromJson(json, BehaviouralAnalysisJson::class.java)
            BehaviouralAnalysis(
                pillars = (parsed.pillars ?: emptyList()).map {
                    BehaviouralPillar(
                        name = it.name ?: "",
                        score = it.score ?: 0,
                        status = it.status ?: "",
                        tasks = it.tasks ?: emptyList(),
                        insight = it.insight ?: "",
                        advice = it.advice ?: ""
                    )
                },
                overallInsight = parsed.overallInsight ?: "",
                criticalPillar = parsed.criticalPillar ?: ""
            )
        } catch (e: Exception) {
            Log.e(TAG, "behaviouralPillars failed", e)
            BehaviouralAnalysis(emptyList(), "", "")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun extractJson(raw: String): String {
        val start = raw.indexOfFirst { it == '{' || it == '[' }
        val end = raw.indexOfLast { it == '}' || it == ']' }
        return if (start >= 0 && end > start) raw.substring(start, end + 1) else raw
    }

    private fun stripBannedSuffixes(name: String, banned: List<String>): String {
        var result = name.trim()
        for (suffix in banned) {
            if (result.endsWith(suffix, ignoreCase = true)) {
                result = result.dropLast(suffix.length).trim().trimEnd(',', '-', ' ')
            }
        }
        return result.ifBlank { name }
    }
}

// ─── JSON DTOs ────────────────────────────────────────────────────────────────

private data class AIResponse(
    val choices: List<AIChoice>?
)

private data class AIChoice(
    val message: AIMessage?
)

private data class AIMessage(
    val content: String?
)

private data class ParsedTaskJson(
    val title: String?,
    val hasReminder: Boolean?,
    val reminderHour: Int?,
    val reminderMinute: Int?
)

private data class StarterListJson(
    val emoji: String?,
    val listName: String?,
    val tasks: List<StarterListTaskJson>?
)

private data class StarterListTaskJson(
    val title: String?,
    val healthType: String?,
    val healthTarget: Double?
)

private data class WeeklyRecapJson(
    val headline: String?,
    val summary: String?,
    val highlight: String?,
    val nudge: String?,
    val grade: String?,
    val gradeReason: String?
)

private data class BehaviouralAnalysisJson(
    val pillars: List<BehaviouralPillarJson>?,
    val overallInsight: String?,
    val criticalPillar: String?
)

private data class BehaviouralPillarJson(
    val name: String?,
    val score: Int?,
    val status: String?,
    val tasks: List<String>?,
    val insight: String?,
    val advice: String?
)
