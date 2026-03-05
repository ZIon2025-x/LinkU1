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

        // Notification channels
        private const val CHANNEL_MESSAGES = "link2ur_messages"
        private const val CHANNEL_TASKS = "link2ur_tasks"
        private const val CHANNEL_DEFAULT = "link2ur_default"
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

    private fun getChannelForType(type: String?): Pair<String, String> {
        return when (type) {
            "message", "task_chat" -> CHANNEL_MESSAGES to "消息通知"
            "task_update", "task_applied", "task_accepted",
            "task_completed", "task_confirmed", "task_cancelled" -> CHANNEL_TASKS to "任务通知"
            else -> CHANNEL_DEFAULT to "Link²Ur 通知"
        }
    }

    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val type = data["type"]
        val (channelId, channelName) = getChannelForType(type)

        // 创建所有通知渠道 (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            listOf(
                Triple(CHANNEL_MESSAGES, "消息通知", NotificationManager.IMPORTANCE_HIGH),
                Triple(CHANNEL_TASKS, "任务通知", NotificationManager.IMPORTANCE_HIGH),
                Triple(CHANNEL_DEFAULT, "Link²Ur 通知", NotificationManager.IMPORTANCE_DEFAULT),
            ).forEach { (id, name, importance) ->
                notificationManager.createNotificationChannel(
                    NotificationChannel(id, name, importance)
                )
            }
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

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF2196F3.toInt())
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
