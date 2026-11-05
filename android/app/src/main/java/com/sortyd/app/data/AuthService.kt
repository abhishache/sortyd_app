package com.sortyd.app.data

import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

data class UserProfile(
    val id: String,
    val email: String,
    val name: String,
    val createdAt: String? = null,
)

data class AuthResult(
    val token: String,
    val user: UserProfile,
)

class AuthService {
    private val baseUrl = "https://api.sortyd.com"
    private val authUrl = "https://auth.sortyd.com"

    suspend fun signUp(email: String, password: String, name: String): Result<AuthResult> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$authUrl/api/auth/signup")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val body = JSONObject().apply {
                put("email", email.trim())
                put("password", password)
                put("name", name.trim())
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = BufferedReader(InputStreamReader(stream)).use { it.readText() }

            if (code in 200..299) {
                val json = JSONObject(resp)
                val token = json.getString("token")
                val uJson = json.getJSONObject("user")
                val user = UserProfile(
                    id = uJson.getString("id"),
                    email = uJson.getString("email"),
                    name = uJson.optString("name", ""),
                    createdAt = if (uJson.has("createdAt") && !uJson.isNull("createdAt")) uJson.getString("createdAt") else null
                )
                Result.success(AuthResult(token, user))
            } else {
                val errorMsg = try {
                    JSONObject(resp).optString("error", "Sign up failed ($code)")
                } catch (_: Exception) {
                    "Sign up failed ($code)"
                }
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signIn(email: String, password: String): Result<AuthResult> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$authUrl/api/auth/signin")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val body = JSONObject().apply {
                put("email", email.trim())
                put("password", password)
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = BufferedReader(InputStreamReader(stream)).use { it.readText() }

            if (code in 200..299) {
                val json = JSONObject(resp)
                val token = json.getString("token")
                val uJson = json.getJSONObject("user")
                val user = UserProfile(
                    id = uJson.getString("id"),
                    email = uJson.getString("email"),
                    name = uJson.optString("name", ""),
                    createdAt = if (uJson.has("createdAt") && !uJson.isNull("createdAt")) uJson.getString("createdAt") else null
                )
                Result.success(AuthResult(token, user))
            } else {
                val errorMsg = try {
                    JSONObject(resp).optString("error", "Sign in failed ($code)")
                } catch (_: Exception) {
                    "Sign in failed ($code)"
                }
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signInWithGoogle(email: String, name: String): Result<AuthResult> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$authUrl/api/auth/google")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val body = JSONObject().apply {
                put("email", email.trim())
                put("name", name.trim())
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = BufferedReader(InputStreamReader(stream)).use { it.readText() }

            if (code in 200..299) {
                val json = JSONObject(resp)
                val token = json.getString("token")
                val uJson = json.getJSONObject("user")
                val user = UserProfile(
                    id = uJson.getString("id"),
                    email = uJson.getString("email"),
                    name = uJson.optString("name", "")
                )
                Result.success(AuthResult(token, user))
            } else {
                val errorMsg = try {
                    JSONObject(resp).optString("error", "Google Sign-In failed ($code)")
                } catch (_: Exception) {
                    "Google Sign-In failed ($code)"
                }
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun pushData(dataJson: JSONObject, token: String, allowDelete: Boolean = true): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/api/user/sync")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val payload = JSONObject().apply {
                put("data", dataJson)
                put("allowDelete", allowDelete)
                put("sourceDevice", "Sortyd Android (${Build.MODEL})")
            }.toString()

            OutputStreamWriter(conn.outputStream).use { it.write(payload) }

            val code = conn.responseCode
            if (code in 200..299) {
                Result.success(true)
            } else {
                val err = BufferedReader(InputStreamReader(conn.errorStream)).use { it.readText() }
                Result.failure(Exception("Sync failed ($code): $err"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun pullData(token: String): Result<JSONObject?> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/api/user/sync")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $token")
                connectTimeout = 15000
                readTimeout = 15000
            }

            val code = conn.responseCode
            if (code in 200..299) {
                val resp = BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
                val json = JSONObject(resp)
                if (json.isNull("data")) {
                    Result.success(null)
                } else {
                    Result.success(json.getJSONObject("data"))
                }
            } else {
                val err = BufferedReader(InputStreamReader(conn.errorStream)).use { it.readText() }
                Result.failure(Exception("Pull failed ($code): $err"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
