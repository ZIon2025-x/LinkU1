package com.link2ur.link2ur

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.stripe.android.connect.EmbeddedComponentManager
import com.stripe.android.connect.AccountManagementController
import com.stripe.android.connect.AccountManagementListener

/**
 * Stripe Connect 账户管理 Activity
 *
 * 用于已完成 onboarding 的 V2 账户更新收款信息。
 * 与 iOS StripeConnectOnboardingHandler.openAccountManagement 对齐。
 */
class StripeConnectAccountManagementActivity : FragmentActivity() {

    companion object {
        private const val TAG = "StripeConnectMgmt"
    }

    private var accountManagementController: AccountManagementController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        EmbeddedComponentManager.onActivityCreate(this)

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
            val viewModel = ViewModelProvider(this, AccountManagementViewModelFactory(
                publishableKey = publishableKey,
                clientSecret = clientSecret
            ))[AccountManagementViewModel::class.java]

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

            accountManagementController!!.show()

        } catch (e: Exception) {
            Log.e(TAG, "AccountManagement: initialization error - ${e.message}", e)
            val resultIntent = Intent().apply {
                putExtra("error", e.message ?: "Initialization error")
            }
            setResult(RESULT_CANCELED, resultIntent)
            finish()
        }
    }

    override fun onBackPressed() {
        super.onBackPressed()
        setResult(RESULT_OK)
        finish()
    }
}

class AccountManagementViewModel(
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

class AccountManagementViewModelFactory(
    private val publishableKey: String,
    private val clientSecret: String
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AccountManagementViewModel::class.java)) {
            return AccountManagementViewModel(publishableKey, clientSecret) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
