package com.link2ur.link2ur

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * FCM 消息处理服务
 * 处理 FCM token 刷新和远程推送消息
 * 通过 companion object 与 MainActivity 的 MethodChannel 通信
 */
class LinkUFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        /** MethodChannel 回调，由 MainActivity 设置 */
        var onTokenRefresh: ((String) -> Unit)? = null
        var onRemoteMessage: ((Map<String, Any?>) -> Unit)? = null

        private const val CHANNEL_ID = "link2ur_default"
        private const val CHANNEL_NAME = "Link²Ur 通知"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)

        // 保存 token 到 SharedPreferences
        getSharedPreferences("push_prefs", Context.MODE_PRIVATE)
            .edit()
            .putString("fcm_token", token)
            .apply()

        // 通知 Flutter 层
        onTokenRefresh?.invoke(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // 构建消息数据
        val messageData = mutableMapOf<String, Any?>()

        // 从 notification payload 获取 title/body
        message.notification?.let {
            messageData["title"] = it.title ?: ""
            messageData["body"] = it.body ?: ""
        }

        // 合并 data payload
        for ((key, value) in message.data) {
            messageData[key] = value
        }

        // 如果 Flutter engine 在运行，转发给 Dart 层
        val callback = onRemoteMessage
        if (callback != null) {
            callback.invoke(messageData)
        } else {
            // App 在后台或未运行，显示系统通知
            showNotification(
                title = messageData["title"] as? String ?: "",
                body = messageData["body"] as? String ?: "",
                data = message.data
            )
        }
    }

    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 创建通知渠道 (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        // 点击通知打开 app，附带 data
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_data", HashMap(data))
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
