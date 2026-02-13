package com.link2ur.link2ur

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.stripe.android.connect.EmbeddedComponentManager
import com.stripe.android.connect.AccountOnboardingController
import com.stripe.android.connect.AccountOnboardingListener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Stripe Connect 入驻 Activity
 *
 * 使用 Stripe Connect Embedded Components SDK 显示账户入驻 UI。
 *
 * 关键设计：fetchClientSecret **每次**被 SDK 调用时都向后端请求全新的 AccountSession client_secret，
 * 彻底避免 "You tried to claim an account session that has already been claimed" 错误。
 *
 * 这样做的原因：
 * 1. Stripe SDK 可能多次调用 fetchClientSecret（初始化、WebView 认证返回、会话过期刷新等）
 * 2. 配置变更（如 Stripe 认证 Chrome Custom Tab 返回）可能导致 Activity 重建
 * 3. 每个 AccountSession client_secret 只能被 claim 一次
 *
 * 参考 Stripe 文档:
 * https://docs.stripe.com/connect/get-started-connect-embedded-components?platform=android
 */
class StripeConnectOnboardingActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "StripeConnectOnboarding"
    }

    private var embeddedComponentManager: EmbeddedComponentManager? = null
    private var accountOnboardingController: AccountOnboardingController? = null

    // 防止 Activity 重建时重复初始化（通过 configChanges 已减少重建，但做双重保护）
    private var isInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 必须在 onCreate 中调用，用于 Stripe SDK 生命周期管理
        EmbeddedComponentManager.onActivityCreate(this)

        if (isInitialized) {
            Log.d(TAG, "Already initialized, skipping duplicate onCreate")
            return
        }

        val publishableKey = intent.getStringExtra("publishableKey")
        val apiBaseUrl = intent.getStringExtra("apiBaseUrl")
        val authToken = intent.getStringExtra("authToken")
        // 初始 secret 仅作为后端不可达时的最后回退
        val fallbackClientSecret = intent.getStringExtra("clientSecret")

        // 调试日志：确认 Flutter 传递的参数
        Log.d(TAG, "publishableKey: ${publishableKey?.take(20)}...")
        Log.d(TAG, "apiBaseUrl: $apiBaseUrl")
        Log.d(TAG, "authToken: ${if (authToken.isNullOrEmpty()) "NULL/EMPTY" else "${authToken.take(8)}...(${authToken.length} chars)"}")
        Log.d(TAG, "fallbackClientSecret: ${if (fallbackClientSecret.isNullOrEmpty()) "NULL/EMPTY" else "${fallbackClientSecret.take(20)}..."}")

        if (publishableKey == null) {
            setResult(RESULT_CANCELED, Intent().apply {
                putExtra("error", "Missing publishableKey")
            })
            finish()
            return
        }

        try {
            embeddedComponentManager = EmbeddedComponentManager(
                publishableKey = publishableKey,
                fetchClientSecret = {
                    // 每次都尝试从后端获取全新的 client_secret
                    val freshSecret = fetchFreshClientSecret(apiBaseUrl, authToken)
                    if (freshSecret != null) {
                        Log.d(TAG, "fetchClientSecret: using fresh secret from backend")
                        freshSecret
                    } else {
                        // 后端不可达时，回退到 Flutter 传入的初始 secret
                        Log.w(TAG, "fetchClientSecret: backend failed, using fallback secret")
                        fallbackClientSecret
                    }
                }
            )

            accountOnboardingController =
                embeddedComponentManager!!.createAccountOnboardingController(this)

            accountOnboardingController!!.listener = object : AccountOnboardingListener {
                override fun onExit() {
                    Log.d(TAG, "Onboarding: onExit called")
                    setResult(RESULT_OK)
                    finish()
                }

                override fun onLoadError(error: Throwable) {
                    Log.e(TAG, "Onboarding: onLoadError - ${error.message}", error)
                    val resultIntent = Intent().apply {
                        putExtra("error", error.message ?: "Unknown error loading onboarding")
                    }
                    setResult(RESULT_CANCELED, resultIntent)
                    finish()
                }
            }

            // 展示入驻 UI
            accountOnboardingController!!.show()
            isInitialized = true

        } catch (e: Exception) {
            Log.e(TAG, "Onboarding: initialization error - ${e.message}", e)
            val resultIntent = Intent().apply {
                putExtra("error", e.message ?: "Initialization error")
            }
            setResult(RESULT_CANCELED, resultIntent)
            finish()
        }
    }

    /**
     * 向后端请求全新的 AccountSession client_secret
     *
     * 认证方式：同时发送 Authorization: Bearer 和 X-Session-ID 两个 header
     * - Authorization: Bearer 防止 sync_csrf_cookie_bearer 的 auto_error 抛出 401
     * - X-Session-ID 让 validate_session() 从 Redis 查找 session 完成实际认证
     */
    private suspend fun fetchFreshClientSecret(
        apiBaseUrl: String?,
        authToken: String?
    ): String? {
        if (apiBaseUrl.isNullOrEmpty() || authToken.isNullOrEmpty()) {
            Log.w(TAG, "Cannot fetch fresh secret: missing apiBaseUrl or authToken")
            return null
        }

        return withContext(Dispatchers.IO) {
            var connection: HttpURLConnection? = null
            try {
                val requestUrl = "$apiBaseUrl/api/stripe/connect/account/onboarding-session"
                Log.d(TAG, "Fetching fresh secret from: $requestUrl")
                Log.d(TAG, "Using X-Session-ID: ${authToken!!.take(8)}...(${authToken.length} chars)")

                val url = URL(requestUrl)
                connection = url.openConnection() as HttpURLConnection
                connection.apply {
                    requestMethod = "POST"
                    // 后端认证流程需要两个 header 配合：
                    // 1. Authorization: Bearer → 让 sync_csrf_cookie_bearer 提取到 credentials（防止 auto_error 抛 401）
                    // 2. X-Session-ID → 让 validate_session() 查找 session 并完成实际认证
                    // validate_session 先于 JWT 校验执行，所以即使 session_id 不是 JWT 也能成功
                    setRequestProperty("Authorization", "Bearer $authToken")
                    setRequestProperty("X-Session-ID", authToken)
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 15000
                    readTimeout = 15000
                    doOutput = true
                    outputStream.write("{}".toByteArray())
                    outputStream.flush()
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = reader.readText()
                    reader.close()

                    val json = JSONObject(response)
                    val clientSecret = json.optString("client_secret", "")
                    if (clientSecret.isNotEmpty()) {
                        Log.d(TAG, "Successfully fetched fresh client secret from backend")
                        clientSecret
                    } else {
                        Log.w(TAG, "Backend returned empty client_secret")
                        null
                    }
                } else {
                    val errorStream = connection.errorStream ?: connection.inputStream
                    val errorReader = BufferedReader(InputStreamReader(errorStream))
                    val errorBody = errorReader.readText()
                    errorReader.close()
                    Log.e(TAG, "Failed to fetch fresh secret: HTTP $responseCode - $errorBody")
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching fresh client secret: ${e.message}", e)
                null
            } finally {
                connection?.disconnect()
            }
        }
    }
}
