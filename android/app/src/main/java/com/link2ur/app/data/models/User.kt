package com.linku.app.data.models

import com.google.gson.annotations.SerializedName

data class User(
    val id: String,
    val username: String,
    val email: String,
    val avatar: String?,
    val phone: String?,
    val city: String?,
    @SerializedName("created_at")
    val createdAt: String
)

data class LoginRequest(
    val email: String,
    val password: String
)

data class LoginResponse(
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("refresh_token")
    val refreshToken: String?,
    val user: User
)

data class RegisterRequest(
    val username: String,
    val email: String,
    val password: String,
    val phone: String?
)

data class UpdateUserProfileRequest(
    val username: String?,
    val phone: String?,
    val city: String?,
    val avatar: String?
)

