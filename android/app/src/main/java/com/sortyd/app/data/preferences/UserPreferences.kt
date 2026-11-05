package com.sortyd.app.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "sortyd_prefs")

class UserPreferences(private val context: Context) {

    // ── Keys ──
    private object Keys {
        val ACTIVE_LIST_ID = stringPreferencesKey("active_list_id")
        val HAS_SEEN_ONBOARDING = booleanPreferencesKey("has_seen_onboarding")
        val IS_DARK_MODE = booleanPreferencesKey("is_dark_mode")
        val SELECTED_FONT = stringPreferencesKey("selected_font")
        val SELECTED_LANGUAGE = stringPreferencesKey("selected_language")
        val INSTALL_DATE = longPreferencesKey("install_date")
        val TASK_COMPLETION_COUNT = intPreferencesKey("task_completion_count")
        val HAS_REQUESTED_REVIEW = booleanPreferencesKey("has_requested_review")
        val HEALTH_GRANTED = booleanPreferencesKey("health_granted")
        val LAST_RESET_DATE = longPreferencesKey("last_reset_date")
        val LAST_RECAP_DATE = longPreferencesKey("last_recap_date")
        val SHOW_EDIT_MODE = booleanPreferencesKey("show_edit_mode")
        val HAS_SHOWN_HEALTH_NOTIFICATION = booleanPreferencesKey("has_shown_health_notification")
        val HAS_SHOWN_REMINDER_NOTIFICATION = booleanPreferencesKey("has_shown_reminder_notification")
        val AUTH_TOKEN = stringPreferencesKey("sortyd_auth_token")
        val AUTH_USER_JSON = stringPreferencesKey("sortyd_auth_user_json")
        val LAST_SYNC_TIME = longPreferencesKey("sortyd_last_sync_timestamp")
    }

    // ── Active list ──
    val activeListId: Flow<String?> = context.dataStore.data.map { it[Keys.ACTIVE_LIST_ID] }
    suspend fun setActiveListId(id: String) {
        context.dataStore.edit { it[Keys.ACTIVE_LIST_ID] = id }
    }

    // ── Onboarding ──
    val hasSeenOnboarding: Flow<Boolean> = context.dataStore.data.map { it[Keys.HAS_SEEN_ONBOARDING] ?: false }
    suspend fun setHasSeenOnboarding(seen: Boolean) {
        context.dataStore.edit { it[Keys.HAS_SEEN_ONBOARDING] = seen }
    }

    // ── Dark mode ──
    val isDarkMode: Flow<Boolean> = context.dataStore.data.map { it[Keys.IS_DARK_MODE] ?: true }
    suspend fun setDarkMode(dark: Boolean) {
        context.dataStore.edit { it[Keys.IS_DARK_MODE] = dark }
    }

    // ── Font ──
    val selectedFont: Flow<String> = context.dataStore.data.map { it[Keys.SELECTED_FONT] ?: "ROUNDED" }
    suspend fun setSelectedFont(font: String) {
        context.dataStore.edit { it[Keys.SELECTED_FONT] = font }
    }

    // ── Language ──
    val selectedLanguage: Flow<String> = context.dataStore.data.map { it[Keys.SELECTED_LANGUAGE] ?: "en" }
    suspend fun setSelectedLanguage(lang: String) {
        context.dataStore.edit { it[Keys.SELECTED_LANGUAGE] = lang }
    }

    // ── Install date ──
    val installDate: Flow<Long> = context.dataStore.data.map { it[Keys.INSTALL_DATE] ?: 0L }
    suspend fun setInstallDate(date: Long) {
        context.dataStore.edit { it[Keys.INSTALL_DATE] = date }
    }

    // ── Task completion count (for review prompt) ──
    val taskCompletionCount: Flow<Int> = context.dataStore.data.map { it[Keys.TASK_COMPLETION_COUNT] ?: 0 }
    suspend fun incrementTaskCompletionCount() {
        context.dataStore.edit { prefs ->
            val current = prefs[Keys.TASK_COMPLETION_COUNT] ?: 0
            prefs[Keys.TASK_COMPLETION_COUNT] = current + 1
        }
    }

    // ── Review prompt ──
    val hasRequestedReview: Flow<Boolean> = context.dataStore.data.map { it[Keys.HAS_REQUESTED_REVIEW] ?: false }
    suspend fun setHasRequestedReview(requested: Boolean) {
        context.dataStore.edit { it[Keys.HAS_REQUESTED_REVIEW] = requested }
    }

    // ── Health Connect ──
    val healthGranted: Flow<Boolean> = context.dataStore.data.map { it[Keys.HEALTH_GRANTED] ?: false }
    suspend fun setHealthGranted(granted: Boolean) {
        context.dataStore.edit { it[Keys.HEALTH_GRANTED] = granted }
    }

    // ── Last daily reset date ──
    val lastResetDate: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_RESET_DATE] ?: 0L }
    suspend fun setLastResetDate(date: Long) {
        context.dataStore.edit { it[Keys.LAST_RESET_DATE] = date }
    }

    val lastRecapDate: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_RECAP_DATE] ?: 0L }
    suspend fun setLastRecapDate(date: Long) {
        context.dataStore.edit { it[Keys.LAST_RECAP_DATE] = date }
    }

    // ── Notifications ──
    val hasShownHealthNotification: Flow<Boolean> = context.dataStore.data.map { it[Keys.HAS_SHOWN_HEALTH_NOTIFICATION] ?: false }
    suspend fun setHasShownHealthNotification(shown: Boolean) {
        context.dataStore.edit { it[Keys.HAS_SHOWN_HEALTH_NOTIFICATION] = shown }
    }

    val hasShownReminderNotification: Flow<Boolean> = context.dataStore.data.map { it[Keys.HAS_SHOWN_REMINDER_NOTIFICATION] ?: false }
    suspend fun setHasShownReminderNotification(shown: Boolean) {
        context.dataStore.edit { it[Keys.HAS_SHOWN_REMINDER_NOTIFICATION] = shown }
    }

    // ── Authentication & Cloud Sync ──
    val authToken: Flow<String?> = context.dataStore.data.map { it[Keys.AUTH_TOKEN] }
    suspend fun setAuthToken(token: String?) {
        context.dataStore.edit {
            if (token != null) it[Keys.AUTH_TOKEN] = token else it.remove(Keys.AUTH_TOKEN)
        }
    }

    val authUserJson: Flow<String?> = context.dataStore.data.map { it[Keys.AUTH_USER_JSON] }
    suspend fun setAuthUserJson(json: String?) {
        context.dataStore.edit {
            if (json != null) it[Keys.AUTH_USER_JSON] = json else it.remove(Keys.AUTH_USER_JSON)
        }
    }

    val lastSyncTime: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_SYNC_TIME] ?: 0L }
    suspend fun setLastSyncTime(time: Long) {
        context.dataStore.edit { it[Keys.LAST_SYNC_TIME] = time }
    }
}
