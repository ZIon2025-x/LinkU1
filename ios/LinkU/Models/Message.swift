//
//  Message.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation

struct Message: Codable, Identifiable {
    let id: Int
    let content: String
    let senderId: Int
    let receiverId: Int
    let taskId: Int?
    let createdAt: String
    let isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case taskId = "task_id"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

struct FleaMarketItem: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let category: String
    let city: String
    let images: [String]
    let sellerId: Int
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, city, images, status
        case sellerId = "seller_id"
        case createdAt = "created_at"
    }
}

struct ImageUploadResponse: Codable {
    let url: String
    let id: Int?
}

