package com.link2ur.link2ur

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val LOCATION_PICKER_REQUEST = 2001
        private const val STRIPE_CONNECT_REQUEST = 2002
    }

    private var pushChannel: MethodChannel? = null
    private var locationPickerChannel: MethodChannel? = null
    private var stripeConnectChannel: MethodChannel? = null
    private var locationPickerResult: MethodChannel.Result? = null
    private var stripeConnectResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 检查是否从通知点击启动
        handleNotificationIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 推送通知 MethodChannel
        pushChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.link2ur/push"
        )
        pushChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceToken" -> {
                    // 先从缓存读取
                    val cached = getSharedPreferences("push_prefs", Context.MODE_PRIVATE)
                        .getString("fcm_token", null)
                    if (cached != null) {
                        result.success(cached)
                    } else {
                        // 从 Firebase 获取
                        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                            if (task.isSuccessful) {
                                val token = task.result
                                getSharedPreferences("push_prefs", Context.MODE_PRIVATE)
                                    .edit().putString("fcm_token", token).apply()
                                result.success(token)
                            } else {
                                result.success(null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 地图选点 MethodChannel
        locationPickerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.link2ur/location_picker"
        )
        locationPickerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openLocationPicker" -> {
                    locationPickerResult = result
                    val args = call.arguments as? Map<*, *>
                    val intent = Intent(this, LocationPickerActivity::class.java).apply {
                        args?.get("initialLatitude")?.let {
                            putExtra(LocationPickerActivity.EXTRA_INITIAL_LAT, (it as Number).toDouble())
                        }
                        args?.get("initialLongitude")?.let {
                            putExtra(LocationPickerActivity.EXTRA_INITIAL_LNG, (it as Number).toDouble())
                        }
                        args?.get("initialAddress")?.let {
                            putExtra(LocationPickerActivity.EXTRA_INITIAL_ADDR, it as String)
                        }
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, LOCATION_PICKER_REQUEST)
                }
                else -> result.notImplemented()
            }
        }

        // Stripe Connect MethodChannel
        stripeConnectChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.link2ur/stripe_connect"
        )
        stripeConnectChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openOnboarding" -> {
                    stripeConnectResult = result
                    val args = call.arguments as? Map<*, *>
                    val publishableKey = args?.get("publishableKey") as? String
                    val clientSecret = args?.get("clientSecret") as? String
                    val apiBaseUrl = args?.get("apiBaseUrl") as? String
                    val authToken = args?.get("authToken") as? String
                    
                    if (publishableKey != null && clientSecret != null) {
                        val intent = Intent(this, StripeConnectOnboardingActivity::class.java).apply {
                            putExtra("publishableKey", publishableKey)
                            putExtra("clientSecret", clientSecret)
                            putExtra("apiBaseUrl", apiBaseUrl)
                            putExtra("authToken", authToken)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, STRIPE_CONNECT_REQUEST)
                    } else {
                        result.error("INVALID_ARGS", "Missing publishableKey or clientSecret", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 设置 FCM Service 回调 → 转发到 Flutter
        LinkUFirebaseMessagingService.onTokenRefresh = { token ->
            runOnUiThread {
                pushChannel?.invokeMethod("onTokenRefresh", token)
            }
        }
        LinkUFirebaseMessagingService.onRemoteMessage = { data ->
            runOnUiThread {
                pushChannel?.invokeMethod("onRemoteMessage", data)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 处理从通知点击打开（app 已在后台）
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        @Suppress("UNCHECKED_CAST")
        val data = intent?.getSerializableExtra("notification_data") as? HashMap<String, String>
        if (data != null) {
            // 延迟发送，等待 Flutter engine 就绪
            window.decorView.postDelayed({
                pushChannel?.invokeMethod("onNotificationTapped", data)
            }, 500)
            // 清除 extra 防止重复处理
            intent?.removeExtra("notification_data")
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == LOCATION_PICKER_REQUEST) {
            val pendingResult = locationPickerResult
            locationPickerResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val map = hashMapOf<String, Any>(
                    "address" to (data.getStringExtra(LocationPickerActivity.RESULT_ADDRESS) ?: ""),
                    "latitude" to data.getDoubleExtra(LocationPickerActivity.RESULT_LATITUDE, 0.0),
                    "longitude" to data.getDoubleExtra(LocationPickerActivity.RESULT_LONGITUDE, 0.0)
                )
                pendingResult?.success(map)
            } else {
                pendingResult?.success(null)
            }
        } else if (requestCode == STRIPE_CONNECT_REQUEST) {
            val pendingResult = stripeConnectResult
            stripeConnectResult = null
            if (resultCode == Activity.RESULT_OK) {
                pendingResult?.success(mapOf("status" to "completed"))
            } else {
                val error = data?.getStringExtra("error")
                if (error != null) {
                    pendingResult?.error("ONBOARDING_FAILED", error, null)
                } else {
                    pendingResult?.success(mapOf("status" to "cancelled"))
                }
            }
        }
    }

    override fun onDestroy() {
        // 清除回调引用，避免内存泄漏
        locationPickerResult = null
        stripeConnectResult = null
        LinkUFirebaseMessagingService.onTokenRefresh = null
        LinkUFirebaseMessagingService.onRemoteMessage = null
        super.onDestroy()
    }
}
