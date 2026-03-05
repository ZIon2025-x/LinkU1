package com.link2ur.link2ur

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 必须继承 FlutterFragmentActivity，否则 flutter_stripe 的 Payment Sheet 无法初始化
/// 见 https://github.com/flutter-stripe/flutter_stripe#android
class MainActivity : FlutterFragmentActivity() {

    private var pushChannel: MethodChannel? = null
    private var locationPickerChannel: MethodChannel? = null
    private var stripeConnectChannel: MethodChannel? = null
    private var locationPickerResult: MethodChannel.Result? = null
    private var stripeConnectResult: MethodChannel.Result? = null

    private lateinit var locationPickerLauncher: ActivityResultLauncher<Intent>
    private lateinit var stripeConnectLauncher: ActivityResultLauncher<Intent>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        locationPickerLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val pendingResult = locationPickerResult
            locationPickerResult = null
            if (result.resultCode == Activity.RESULT_OK && result.data != null) {
                val data = result.data!!
                val map = hashMapOf<String, Any>(
                    "address" to (data.getStringExtra(LocationPickerActivity.RESULT_ADDRESS) ?: ""),
                    "latitude" to data.getDoubleExtra(LocationPickerActivity.RESULT_LATITUDE, 0.0),
                    "longitude" to data.getDoubleExtra(LocationPickerActivity.RESULT_LONGITUDE, 0.0)
                )
                pendingResult?.success(map)
            } else {
                pendingResult?.success(null)
            }
        }

        stripeConnectLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val pendingResult = stripeConnectResult
            stripeConnectResult = null
            if (result.resultCode == Activity.RESULT_OK) {
                pendingResult?.success(mapOf("status" to "completed"))
            } else {
                val error = result.data?.getStringExtra("error")
                if (error != null) {
                    pendingResult?.error("ONBOARDING_FAILED", error, null)
                } else {
                    pendingResult?.success(mapOf("status" to "cancelled"))
                }
            }
        }

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
                    locationPickerLauncher.launch(intent)
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

                    if (publishableKey != null && clientSecret != null) {
                        val intent = Intent(this, StripeConnectOnboardingActivity::class.java).apply {
                            putExtra("publishableKey", publishableKey)
                            putExtra("clientSecret", clientSecret)
                        }
                        stripeConnectLauncher.launch(intent)
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

    override fun onDestroy() {
        // 清除回调引用，避免内存泄漏
        locationPickerResult = null
        stripeConnectResult = null
        LinkUFirebaseMessagingService.onTokenRefresh = null
        LinkUFirebaseMessagingService.onRemoteMessage = null
        super.onDestroy()
    }
}
