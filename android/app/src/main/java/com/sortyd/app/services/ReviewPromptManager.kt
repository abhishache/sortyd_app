package com.sortyd.app.services

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory

object ReviewPromptManager {

    private const val PREFS = "sortyd_review_prefs"
    private const val KEY_INSTALL_DATE = "install_date_ms"
    private const val KEY_HAS_REVIEWED = "has_reviewed"
    private const val KEY_LAST_PROMPT_DATE = "last_prompt_date_ms"

    private const val PROMPT_INTERVAL_DAYS = 7L
    private val oneDayMs = 24 * 60 * 60 * 1000L

    fun maybeRequestReview(activity: Activity) {
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        if (prefs.getBoolean(KEY_HAS_REVIEWED, false)) return

        val now = System.currentTimeMillis()

        // Record install date on first call
        if (!prefs.contains(KEY_INSTALL_DATE)) {
            prefs.edit().putLong(KEY_INSTALL_DATE, now).apply()
            return
        }

        val installDate = prefs.getLong(KEY_INSTALL_DATE, now)
        val daysSinceInstall = (now - installDate) / oneDayMs
        val lastPrompt = prefs.getLong(KEY_LAST_PROMPT_DATE, 0L)
        val daysSinceLastPrompt = (now - lastPrompt) / oneDayMs

        // Ask only after a week of real use, then no more than once every seven days.
        val shouldPrompt = daysSinceInstall >= PROMPT_INTERVAL_DAYS &&
            (lastPrompt == 0L || daysSinceLastPrompt >= PROMPT_INTERVAL_DAYS)

        if (!shouldPrompt) return

        prefs.edit().putLong(KEY_LAST_PROMPT_DATE, now).apply()

        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) {
                manager.launchReviewFlow(activity, request.result).addOnCompleteListener {
                    // Play does not expose whether text was submitted. A completed native
                    // review flow is the strongest signal available, so never ask again.
                    prefs.edit().putBoolean(KEY_HAS_REVIEWED, true).apply()
                }
            }
        }
    }
}
