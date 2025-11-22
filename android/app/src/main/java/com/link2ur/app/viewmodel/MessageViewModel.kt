package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.api.SendMessageRequest
import com.linku.app.data.models.Conversation
import com.linku.app.data.models.Message
import com.linku.app.data.websocket.WebSocketService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject

class MessageViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    private var wsSubscription: (() -> Unit)? = null
    
    private val _conversations = MutableStateFlow<List<Conversation>>(emptyList())
    val conversations: StateFlow<List<Conversation>> = _conversations.asStateFlow()
    
    private val _messages = MutableStateFlow<List<Message>>(emptyList())
    val messages: StateFlow<List<Message>> = _messages.asStateFlow()
    
    private val _currentConversationId = MutableStateFlow<Int?>(null)
    val currentConversationId: StateFlow<Int?> = _currentConversationId.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    private val _unreadCount = MutableStateFlow(0)
    val unreadCount: StateFlow<Int> = _unreadCount.asStateFlow()
    
    init {
        setupWebSocket()
    }
    
    fun loadConversations() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val response = apiService.getConversations()
                if (response.isSuccessful) {
                    _conversations.value = response.body()?.conversations ?: emptyList()
                } else {
                    _errorMessage.value = "加载失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    fun loadMessages(conversationId: Int) {
        viewModelScope.launch {
            _isLoading.value = true
            _currentConversationId.value = conversationId
            
            try {
                val response = apiService.getMessages(conversationId)
                if (response.isSuccessful) {
                    _messages.value = response.body()?.messages ?: emptyList()
                } else {
                    _errorMessage.value = "加载失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    fun sendMessage(content: String, receiverId: Int, taskId: Int? = null) {
        // 优先通过WebSocket发送
        if (WebSocketService.instance.isConnected.value) {
            val message = mapOf(
                "type" to "message",
                "content" to content,
                "receiver_id" to receiverId,
                "task_id" to (taskId ?: JSONObject.NULL)
            )
            WebSocketService.instance.sendJSON(message)
            
            // 乐观更新
            val tempMessage = Message(
                id = System.currentTimeMillis().toInt(),
                content = content,
                senderId = "", // 需要从AuthViewModel获取
                receiverId = receiverId.toString(),
                taskId = taskId,
                createdAt = java.time.Instant.now().toString(),
                isRead = false
            )
            _messages.value = _messages.value + tempMessage
        } else {
            // WebSocket未连接，使用HTTP API
            viewModelScope.launch {
                try {
                    val response = apiService.sendMessage(
                        SendMessageRequest(content, receiverId, taskId)
                    )
                    if (response.isSuccessful) {
                        _messages.value = _messages.value + (response.body() ?: return@launch)
                    }
                } catch (e: Exception) {
                    _errorMessage.value = "发送失败: ${e.message}"
                }
            }
        }
    }
    
    fun refreshUnreadCount() {
        viewModelScope.launch {
            try {
                val response = apiService.getUnreadCount()
                if (response.isSuccessful) {
                    _unreadCount.value = response.body()?.count ?: 0
                }
            } catch (e: Exception) {
                // 静默失败
            }
        }
    }
    
    private fun setupWebSocket() {
        wsSubscription = WebSocketService.instance.subscribe { message ->
            if (message is JSONObject) {
                val type = message.optString("type", "")
                if (type == "message_sent") {
                    // 收到新消息通知，刷新消息列表
                    val conversationId = _currentConversationId.value
                    if (conversationId != null) {
                        loadMessages(conversationId)
                    }
                    refreshUnreadCount()
                }
            }
        }
    }
    
    override fun onCleared() {
        super.onCleared()
        wsSubscription?.invoke()
    }
}

