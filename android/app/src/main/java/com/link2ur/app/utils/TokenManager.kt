package com.linku.app.utils

import android.content.Context
import android.content.SharedPreferences
import com.linku.app.LinkUApplication

object TokenManager {
    private const val PREFS_NAME = "linku_prefs"
    private const val KEY_TOKEN = "auth_token"
    private const val KEY_USER_ID = "user_id"
    
    private var context: Context? = null
    
    fun init(context: Context) {
        this.context = context.applicationContext
    }
    
    private val prefs: SharedPreferences
        get() = context!!.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    fun saveToken(token: String) {
        prefs.edit().putString(KEY_TOKEN, token).apply()
    }
    
    fun getToken(): String? {
        return prefs.getString(KEY_TOKEN, null)
    }
    
    fun deleteToken() {
        prefs.edit().remove(KEY_TOKEN).apply()
    }
    
    fun saveUserId(userId: String) {
        prefs.edit().putString(KEY_USER_ID, userId).apply()
    }
    
    fun getUserId(): String? {
        return prefs.getString(KEY_USER_ID, null)
    }
    
    fun deleteUserId() {
        prefs.edit().remove(KEY_USER_ID).apply()
    }
    
    fun clear() {
        prefs.edit().clear().apply()
    }
}

