package com.linku.app.data.models

import com.google.gson.annotations.SerializedName

data class Message(
    val id: Int,
    val content: String,
    @SerializedName("sender_id")
    val senderId: String,
    @SerializedName("receiver_id")
    val receiverId: String,
    @SerializedName("task_id")
    val taskId: Int?,
    @SerializedName("created_at")
    val createdAt: String,
    @SerializedName("is_read")
    val isRead: Boolean
)

data class Conversation(
    val id: Int,
    @SerializedName("other_user")
    val otherUser: User,
    @SerializedName("last_message")
    val lastMessage: Message?,
    @SerializedName("unread_count")
    val unreadCount: Int,
    @SerializedName("updated_at")
    val updatedAt: String
)

data class ConversationListResponse(
    val conversations: List<Conversation>
)

data class MessageListResponse(
    val messages: List<Message>,
    val total: Int,
    val page: Int
)

data class UnreadCountResponse(
    val count: Int
)

data class FleaMarketItem(
    val id: Int,
    val title: String,
    val description: String,
    val price: Double,
    val category: String,
    val city: String,
    val images: List<String>,
    @SerializedName("seller_id")
    val sellerId: Int,
    val status: String,
    @SerializedName("created_at")
    val createdAt: String
)

data class FleaMarketItemListResponse(
    val items: List<FleaMarketItem>,
    val total: Int,
    val page: Int,
    @SerializedName("page_size")
    val pageSize: Int
)

data class FleaMarketCategoriesResponse(
    val success: Boolean,
    val categories: List<String>
)

data class ImageUploadResponse(
    val url: String,
    val id: Int?
)

