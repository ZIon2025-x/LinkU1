package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.models.Task
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class HomeViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    
    private val _featuredTasks = MutableStateFlow<List<Task>>(emptyList())
    val featuredTasks: StateFlow<List<Task>> = _featuredTasks.asStateFlow()
    
    private val _recentTasks = MutableStateFlow<List<Task>>(emptyList())
    val recentTasks: StateFlow<List<Task>> = _recentTasks.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    fun loadData() {
        viewModelScope.launch {
            _isLoading.value = true
            
            try {
                val response = apiService.getTasks()
                if (response.isSuccessful) {
                    val tasks = response.body()?.tasks ?: emptyList()
                    _featuredTasks.value = tasks.take(10)
                    _recentTasks.value = tasks
                }
            } catch (e: Exception) {
                // 处理错误
            } finally {
                _isLoading.value = false
            }
        }
    }
}

