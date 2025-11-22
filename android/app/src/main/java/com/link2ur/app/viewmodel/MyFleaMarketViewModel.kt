package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.models.FleaMarketItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MyFleaMarketViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    
    private val _items = MutableStateFlow<List<FleaMarketItem>>(emptyList())
    val items: StateFlow<List<FleaMarketItem>> = _items.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    fun loadMyItems(status: String? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val response = apiService.getMyFleaMarketItems(status = status)
                if (response.isSuccessful) {
                    _items.value = response.body()?.items ?: emptyList()
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
}

