package com.link2ur.link2ur

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.addCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.stripe.android.connect.EmbeddedComponentManager
import com.stripe.android.connect.AccountOnboardingController
import com.stripe.android.connect.AccountOnboardingListener
import com.stripe.android.connect.AccountOnboardingProps

/**
 * Stripe Connect 入驻 Activity
 *
 * 使用 Stripe Connect Embedded Components SDK 显示账户入驻 UI。
 *
 * 架构遵循 Stripe 官方文档推荐：
 * - 继承 FragmentActivity（Stripe SDK 要求）
 * - 使用 ViewModel 持有 EmbeddedComponentManager（防止配置变更导致状态丢失）
 * - fetchClientSecret 直接返回 Flutter 层传入的 clientSecret（与 iOS 行为一致）
 *
 * 参考 Stripe 文档:
 * https://docs.stripe.com/connect/get-started-connect-embedded-components?platform=android
 */
class StripeConnectOnboardingActivity : FragmentActivity() {

    companion object {
        private const val TAG = "StripeConnectOnboarding"
    }

    private var accountOnboardingController: AccountOnboardingController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 必须在 onCreate 中调用，用于 Stripe SDK 生命周期管理
        EmbeddedComponentManager.onActivityCreate(this)

        // 系统返回键处理
        onBackPressedDispatcher.addCallback(this) {
            setResult(RESULT_CANCELED)
            finish()
        }

        val publishableKey = intent.getStringExtra("publishableKey")
        val clientSecret = intent.getStringExtra("clientSecret")

        // 调试日志
        Log.d(TAG, "publishableKey: ${publishableKey?.take(20)}...")
        Log.d(TAG, "clientSecret: ${if (clientSecret.isNullOrEmpty()) "NULL/EMPTY" else "${clientSecret.take(20)}..."}")

        if (publishableKey == null || clientSecret == null) {
            setResult(RESULT_CANCELED, Intent().apply {
                putExtra("error", "Missing publishableKey or clientSecret")
            })
            finish()
            return
        }

        try {
            // 使用 ViewModel 持有 EmbeddedComponentManager（Stripe 文档推荐）
            // 防止 Chrome Custom Tab 返回等配置变更导致 Manager 被销毁重建
            val viewModel = ViewModelProvider(this, OnboardingViewModelFactory(
                publishableKey = publishableKey,
                clientSecret = clientSecret
            ))[OnboardingViewModel::class.java]

            // 与 iOS 一致的 collectionOptions（收集 eventuallyDue 要求 + 包含 futureRequirements）
            val collectionOptions = AccountOnboardingProps.CollectionOptions(
                fields = AccountOnboardingProps.FieldOption.EVENTUALLY_DUE,
                futureRequirements = AccountOnboardingProps.FutureRequirementOption.INCLUDE
            )

            accountOnboardingController =
                viewModel.embeddedComponentManager.createAccountOnboardingController(
                    activity = this,
                    props = AccountOnboardingProps(
                        fullTermsOfServiceUrl = "https://link2ur.com/terms",
                        recipientTermsOfServiceUrl = "https://link2ur.com/terms",
                        privacyPolicyUrl = "https://link2ur.com/privacy",
                        collectionOptions = collectionOptions
                    )
                )

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

            // 在 Stripe 内容上方叠加关闭按钮栏
            addCloseBar()

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
     * 在页面顶部叠加一个半透明关闭按钮栏，
     * 使用 addContentView 覆盖在 Stripe 嵌入式组件之上。
     */
    private fun addCloseBar() {
        val dp = { value: Int ->
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                value.toFloat(),
                resources.displayMetrics
            ).toInt()
        }

        // 顶部栏容器
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.WHITE)
            elevation = 4f
            setPadding(dp(4), 0, dp(16), 0)
        }

        // 关闭按钮（←）
        val closeButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setBackgroundResource(android.R.attr.selectableItemBackgroundBorderless.let { attr ->
                val outValue = TypedValue()
                theme.resolveAttribute(attr, outValue, true)
                outValue.resourceId
            })
            contentDescription = "Close"
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }
        topBar.addView(closeButton, LinearLayout.LayoutParams(dp(48), dp(48)))

        // 标题
        val title = TextView(this).apply {
            text = "Stripe Connect"
            setTextColor(Color.BLACK)
            textSize = 18f
            setPadding(dp(8), 0, 0, 0)
        }
        topBar.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        // 用 FrameLayout 包裹，处理状态栏 insets
        val wrapper = FrameLayout(this)
        wrapper.addView(topBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.TOP
        })

        // 处理状态栏高度，避免被遮挡
        ViewCompat.setOnApplyWindowInsetsListener(wrapper) { v, insets ->
            val statusBarHeight = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top
            topBar.setPadding(topBar.paddingLeft, statusBarHeight, topBar.paddingRight, 0)
            insets
        }

        addContentView(wrapper, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ))
    }
}

/**
 * ViewModel 持有 EmbeddedComponentManager，在配置变更（如 Chrome Custom Tab 返回）时保持状态。
 * 这是 Stripe 官方文档推荐的做法。
 */
class OnboardingViewModel(
    publishableKey: String,
    clientSecret: String
) : ViewModel() {
    val embeddedComponentManager: EmbeddedComponentManager = EmbeddedComponentManager(
        publishableKey = publishableKey,
        fetchClientSecret = {
            Log.d("StripeConnectOnboarding", "fetchClientSecret: returning client secret from Flutter")
            clientSecret
        }
    )
}

/**
 * ViewModelFactory 用于向 ViewModel 传递构造参数
 */
class OnboardingViewModelFactory(
    private val publishableKey: String,
    private val clientSecret: String
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(OnboardingViewModel::class.java)) {
            return OnboardingViewModel(publishableKey, clientSecret) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
