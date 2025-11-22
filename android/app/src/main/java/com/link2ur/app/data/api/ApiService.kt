package com.linku.app.data.api

import com.google.gson.annotations.SerializedName
import com.linku.app.data.models.*
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    // 认证
    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>
    
    @POST("api/auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<LoginResponse>
    
    // 任务
    @GET("api/tasks")
    suspend fun getTasks(
        @Query("task_type") taskType: String? = null,
        @Query("location") location: String? = null,
        @Query("keyword") keyword: String? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): Response<TaskListResponse>
    
    @GET("api/tasks/{id}")
    suspend fun getTask(@Path("id") id: Int): Response<Task>
    
    @POST("api/tasks")
    suspend fun createTask(@Body task: CreateTaskRequest): Response<Task>
    
    @GET("api/users/tasks")
    suspend fun getMyTasks(@Query("status") status: String? = null): Response<TaskListResponse>
    
    // 跳蚤市场
    @GET("api/flea-market/items")
    suspend fun getFleaMarketItems(
        @Query("category") category: String? = null,
        @Query("keyword") keyword: String? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): Response<FleaMarketItemListResponse>
    
    @GET("api/flea-market/categories")
    suspend fun getFleaMarketCategories(): Response<FleaMarketCategoriesResponse>
    
    @GET("api/users/flea-market/items")
    suspend fun getMyFleaMarketItems(@Query("status") status: String? = null): Response<FleaMarketItemListResponse>
    
    // 图片上传
    @Multipart
    @POST("api/upload/image")
    suspend fun uploadImage(@Part file: okhttp3.MultipartBody.Part): Response<ImageUploadResponse>
    
    // 消息
    @GET("api/users/conversations")
    suspend fun getConversations(): Response<ConversationListResponse>
    
    @GET("api/users/conversations/{id}/messages")
    suspend fun getMessages(
        @Path("id") conversationId: Int,
        @Query("page") page: Int = 1
    ): Response<MessageListResponse>
    
    @POST("api/messages")
    suspend fun sendMessage(@Body request: SendMessageRequest): Response<Message>
    
    @GET("api/users/messages/unread/count")
    suspend fun getUnreadCount(): Response<UnreadCountResponse>
    
    // 用户资料
    @GET("api/users/profile/me")
    suspend fun getUserProfile(): Response<User>
    
    @PUT("api/users/profile/me")
    suspend fun updateUserProfile(@Body profile: UpdateUserProfileRequest): Response<User>
}

data class SendMessageRequest(
    val content: String,
    @SerializedName("receiver_id")
    val receiverId: Int,
    @SerializedName("task_id")
    val taskId: Int? = null
)

