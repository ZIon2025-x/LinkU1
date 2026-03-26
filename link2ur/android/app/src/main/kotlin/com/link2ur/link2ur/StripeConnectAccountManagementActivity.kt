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
import com.stripe.android.connect.AccountManagementController
import com.stripe.android.connect.AccountManagementListener

/**
 * Stripe Connect 账户管理 Activity
 *
 * 使用 Stripe Connect Embedded Components SDK 显示账户管理 UI。
 * 用于已完成 onboarding 的 V2 账户查看和编辑收款信息、银行卡等。
 *
 * 架构与 StripeConnectOnboardingActivity 一致：
 * - 继承 FragmentActivity（Stripe SDK 要求）
 * - 使用 ViewModel 持有 EmbeddedComponentManager（防止配置变更导致状态丢失）
 * - fetchClientSecret 直接返回 Flutter 层传入的 clientSecret
 *
 * 需要 com.stripe:connect:23.0+ （22.8.0 不支持 AccountManagement）
 */
class StripeConnectAccountManagementActivity : FragmentActivity() {

    companion object {
        private const val TAG = "StripeConnectMgmt"
    }

    private var accountManagementController: AccountManagementController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 必须在 onCreate 中调用，用于 Stripe SDK 生命周期管理
        EmbeddedComponentManager.onActivityCreate(this)

        // 系统返回键处理
        onBackPressedDispatcher.addCallback(this) {
            setResult(RESULT_OK)
            finish()
        }

        val publishableKey = intent.getStringExtra("publishableKey")
        val clientSecret = intent.getStringExtra("clientSecret")

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
            val viewModel = ViewModelProvider(this, AccountMgmtViewModelFactory(
                publishableKey = publishableKey,
                clientSecret = clientSecret
            ))[AccountMgmtViewModel::class.java]

            accountManagementController =
                viewModel.embeddedComponentManager.createAccountManagementController(
                    activity = this
                )

            accountManagementController!!.listener = object : AccountManagementListener {
                override fun onLoadError(error: Throwable) {
                    Log.e(TAG, "AccountManagement: onLoadError - ${error.message}", error)
                    val resultIntent = Intent().apply {
                        putExtra("error", error.message ?: "Unknown error loading account management")
                    }
                    setResult(RESULT_CANCELED, resultIntent)
                    finish()
                }
            }

            // 展示账户管理 UI
            accountManagementController!!.show()

            // 在 Stripe 内容上方叠加关闭按钮栏
            addCloseBar()

        } catch (e: Exception) {
            Log.e(TAG, "AccountManagement: initialization error - ${e.message}", e)
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

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.WHITE)
            elevation = 4f
            setPadding(dp(4), 0, dp(16), 0)
        }

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
                setResult(RESULT_OK)
                finish()
            }
        }
        topBar.addView(closeButton, LinearLayout.LayoutParams(dp(48), dp(48)))

        val title = TextView(this).apply {
            text = "Account Management"
            setTextColor(Color.BLACK)
            textSize = 18f
            setPadding(dp(8), 0, 0, 0)
        }
        topBar.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        val wrapper = FrameLayout(this)
        wrapper.addView(topBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.TOP
        })

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
 * ViewModel 持有 EmbeddedComponentManager，在配置变更时保持状态。
 */
class AccountMgmtViewModel(
    publishableKey: String,
    clientSecret: String
) : ViewModel() {
    val embeddedComponentManager: EmbeddedComponentManager = EmbeddedComponentManager(
        publishableKey = publishableKey,
        fetchClientSecret = {
            Log.d("StripeConnectMgmt", "fetchClientSecret: returning client secret from Flutter")
            clientSecret
        }
    )
}

class AccountMgmtViewModelFactory(
    private val publishableKey: String,
    private val clientSecret: String
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AccountMgmtViewModel::class.java)) {
            return AccountMgmtViewModel(publishableKey, clientSecret) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
