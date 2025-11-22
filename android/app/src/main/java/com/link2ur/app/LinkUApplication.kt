package com.linku.app

import android.app.Application
import com.linku.app.utils.TokenManager

class LinkUApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // 初始化应用
        TokenManager.init(this)
    }
}

