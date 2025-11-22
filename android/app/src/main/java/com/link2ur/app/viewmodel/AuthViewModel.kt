package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.models.LoginRequest
import com.linku.app.data.models.RegisterRequest
import com.linku.app.data.models.User
import com.linku.app.data.websocket.WebSocketService
import com.linku.app.utils.TokenManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AuthViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    
    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()
    
    private val _currentUser = MutableStateFlow<User?>(null)
    val currentUser: StateFlow<User?> = _currentUser.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    init {
        // 检查本地存储的token
        val token = TokenManager.getToken()
        if (token != null) {
            // 验证token有效性
            validateToken()
        }
    }
    
    fun login(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val response = apiService.login(LoginRequest(email, password))
                if (response.isSuccessful) {
                    val loginResponse = response.body()!!
                    TokenManager.saveToken(loginResponse.accessToken)
                    TokenManager.saveUserId(loginResponse.user.id)
                    _currentUser.value = loginResponse.user
                    _isAuthenticated.value = true
                    
                    // 连接WebSocket
                    WebSocketService.instance.connect(loginResponse.user.id)
                } else {
                    _errorMessage.value = "登录失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    fun register(username: String, email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val response = apiService.register(RegisterRequest(username, email, password, null))
                if (response.isSuccessful) {
                    val loginResponse = response.body()!!
                    TokenManager.saveToken(loginResponse.accessToken)
                    TokenManager.saveUserId(loginResponse.user.id)
                    _currentUser.value = loginResponse.user
                    _isAuthenticated.value = true
                    
                    // 连接WebSocket
                    WebSocketService.instance.connect(loginResponse.user.id)
                } else {
                    _errorMessage.value = "注册失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    fun logout() {
        TokenManager.clear()
        _currentUser.value = null
        _isAuthenticated.value = false
        WebSocketService.instance.disconnect()
    }
    
    private fun validateToken() {
        viewModelScope.launch {
            try {
                val response = apiService.getUserProfile()
                if (response.isSuccessful) {
                    _currentUser.value = response.body()
                    _isAuthenticated.value = true
                    
                    // 连接WebSocket
                    val userId = TokenManager.getUserId()
                    if (userId != null) {
                        WebSocketService.instance.connect(userId)
                    }
                } else {
                    // Token无效，清除
                    TokenManager.clear()
                }
            } catch (e: Exception) {
                // 验证失败，清除token
                TokenManager.clear()
            }
        }
    }
}

