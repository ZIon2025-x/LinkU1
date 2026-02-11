package com.link2ur.link2ur

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.stripe.android.connect.EmbeddedComponentManager
import com.stripe.android.connect.AccountOnboardingController
import com.stripe.android.connect.AccountOnboardingListener

class StripeConnectOnboardingActivity : AppCompatActivity() {

    private lateinit var embeddedComponentManager: EmbeddedComponentManager
    private lateinit var accountOnboardingController: AccountOnboardingController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize EmbeddedComponentManager for the activity lifecycle
        EmbeddedComponentManager.onActivityCreate(this)

        val publishableKey = intent.getStringExtra("publishableKey")
        val clientSecret = intent.getStringExtra("clientSecret")

        if (publishableKey == null || clientSecret == null) {
            setResult(RESULT_CANCELED, Intent().apply {
                putExtra("error", "Missing publishableKey or clientSecret")
            })
            finish()
            return
        }

        try {
            embeddedComponentManager = EmbeddedComponentManager(
                publishableKey = publishableKey,
                fetchClientSecret = { clientSecret }
            )

            accountOnboardingController = embeddedComponentManager.createAccountOnboardingController(this)
            
            accountOnboardingController.listener = object : AccountOnboardingListener {
                override fun onExit() {
                    // User exited the onboarding flow (completed or closed)
                    setResult(RESULT_OK)
                    finish()
                }

                override fun onLoadError(error: Throwable) {
                    // Error loading the component
                    val resultIntent = Intent().apply {
                        putExtra("error", error.message ?: "Unknown error loading onboarding")
                    }
                    setResult(RESULT_CANCELED, resultIntent)
                    finish()
                }
            }

            // Show the onboarding UI
            accountOnboardingController.show()

        } catch (e: Exception) {
            val resultIntent = Intent().apply {
                putExtra("error", e.message ?: "Initialization error")
            }
            setResult(RESULT_CANCELED, resultIntent)
            finish()
        }
    }
}
