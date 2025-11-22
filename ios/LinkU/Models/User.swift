//
//  User.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let avatar: String?
    let phone: String?
    let city: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, avatar, phone, city
        case createdAt = "created_at"
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let phone: String?
}

