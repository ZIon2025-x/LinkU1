package com.link2ur.link2ur

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.fragment.app.FragmentActivity

/**
 * Stripe Connect 账户管理 Activity
 *
 * 注意：Android Stripe Connect SDK (22.8.0) 尚未提供 AccountManagementController。
 * iOS 端通过 @_spi(PrivateBetaConnect) 私有 API 可用，Android 暂不支持嵌入式账户管理。
 * 此 Activity 直接返回错误，由 Flutter 层处理降级逻辑。
 */
class StripeConnectAccountManagementActivity : FragmentActivity() {

    companion object {
        private const val TAG = "StripeConnectMgmt"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.w(TAG, "AccountManagement embedded component is not available in Android Stripe Connect SDK 22.8.0")

        setResult(RESULT_CANCELED, Intent().apply {
            putExtra("error", "Account management is not yet supported on Android. Please use iOS or contact support.")
        })
        finish()
    }
}
