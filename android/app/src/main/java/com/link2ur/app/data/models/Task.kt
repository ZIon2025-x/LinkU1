package com.linku.app.data.models

import com.google.gson.annotations.SerializedName

data class Task(
    val id: Int,
    val title: String,
    val description: String,
    @SerializedName("task_type")
    val taskType: String,
    val location: String,
    val reward: Double,
    val status: TaskStatus,
    @SerializedName("created_at")
    val createdAt: String,
    @SerializedName("updated_at")
    val updatedAt: String?,
    @SerializedName("poster_id")
    val posterId: String,
    @SerializedName("taker_id")
    val takerId: String?,
    val images: List<String>?,
    val deadline: String?,
    @SerializedName("is_flexible")
    val isFlexible: Int?
) {
    // 兼容属性
    val category: String get() = taskType
    val city: String get() = location
    val price: Double? get() = reward
}

enum class TaskStatus {
    @SerializedName("open")
    OPEN,
    @SerializedName("in_progress")
    IN_PROGRESS,
    @SerializedName("completed")
    COMPLETED,
    @SerializedName("cancelled")
    CANCELLED
}

data class TaskListResponse(
    val tasks: List<Task>,
    val total: Int,
    val page: Int,
    @SerializedName("page_size")
    val pageSize: Int
)

data class CreateTaskRequest(
    val title: String,
    val description: String,
    @SerializedName("task_type")
    val taskType: String,
    val location: String,
    val reward: Double,
    val images: List<String>?,
    val deadline: String?,
    @SerializedName("is_flexible")
    val isFlexible: Int,
    @SerializedName("is_public")
    val isPublic: Int
)

