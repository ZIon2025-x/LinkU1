package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.models.CreateTaskRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class PublishTaskViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    private val _publishSuccess = MutableStateFlow(false)
    val publishSuccess: StateFlow<Boolean> = _publishSuccess.asStateFlow()
    
    fun publishTask(
        title: String,
        description: String,
        taskType: String,
        location: String,
        reward: Double,
        deadline: String?,
        isFlexible: Int
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            _publishSuccess.value = false
            
            try {
                val request = CreateTaskRequest(
                    title = title,
                    description = description,
                    taskType = taskType,
                    location = location,
                    reward = reward,
                    images = null,
                    deadline = deadline,
                    isFlexible = isFlexible,
                    isPublic = 1
                )
                
                val response = apiService.createTask(request)
                if (response.isSuccessful) {
                    _publishSuccess.value = true
                } else {
                    _errorMessage.value = "发布失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
}

