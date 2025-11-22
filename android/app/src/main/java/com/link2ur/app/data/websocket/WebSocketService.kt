package com.linku.app.data.websocket

import android.util.Log
import com.linku.app.utils.TokenManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.*
import okio.ByteString
import org.json.JSONObject

class WebSocketService : WebSocketListener() {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient()
    
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    
    private val _receivedMessage = MutableStateFlow<Any?>(null)
    val receivedMessage: StateFlow<Any?> = _receivedMessage.asStateFlow()
    
    // 消息处理器列表
    private val messageHandlers = mutableListOf<(Any) -> Unit>()
    
    fun connect(userId: String) {
        val url = "wss://api.link2ur.com/ws/chat/$userId"
        val request = Request.Builder()
            .url(url)
            .build()
        
        webSocket = client.newWebSocket(request, this)
        Log.d("WebSocket", "正在连接到: $url")
    }
    
    fun send(message: String) {
        webSocket?.send(message) ?: run {
            Log.w("WebSocket", "WebSocket未连接，无法发送消息")
        }
    }
    
    fun sendJSON(json: Map<String, Any>) {
        val jsonString = JSONObject(json).toString()
        send(jsonString)
    }
    
    fun subscribe(handler: (Any) -> Unit): () -> Unit {
        messageHandlers.add(handler)
        return {
            messageHandlers.remove(handler)
        }
    }
    
    fun disconnect() {
        webSocket?.close(1000, "正常关闭")
        webSocket = null
        _isConnected.value = false
    }
    
    override fun onOpen(webSocket: WebSocket, response: Response) {
        Log.d("WebSocket", "连接成功")
        _isConnected.value = true
    }
    
    override fun onMessage(webSocket: WebSocket, text: String) {
        Log.d("WebSocket", "收到消息: $text")
        try {
            val json = JSONObject(text)
            
            // 处理心跳消息
            val type = json.optString("type", "")
            if (type == "ping") {
                sendJSON(mapOf("type" to "pong"))
                return
            }
            if (type == "pong" || type == "heartbeat") {
                return
            }
            
            // 通知所有订阅者
            _receivedMessage.value = json
            messageHandlers.forEach { handler ->
                try {
                    handler(json)
                } catch (e: Exception) {
                    Log.e("WebSocket", "消息处理错误", e)
                }
            }
        } catch (e: Exception) {
            Log.e("WebSocket", "消息解析错误", e)
        }
    }
    
    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        onMessage(webSocket, bytes.utf8())
    }
    
    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        Log.d("WebSocket", "连接关闭: $code - $reason")
        _isConnected.value = false
    }
    
    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        Log.d("WebSocket", "连接已关闭: $code - $reason")
        _isConnected.value = false
    }
    
    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        Log.e("WebSocket", "连接失败", t)
        _isConnected.value = false
        // 实现重连逻辑
        reconnect()
    }
    
    private fun reconnect() {
        val userId = TokenManager.getUserId()
        if (userId != null) {
            // 延迟重连
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                connect(userId)
            }, 3000)
        }
    }
    
    companion object {
        val instance = WebSocketService()
    }
}

