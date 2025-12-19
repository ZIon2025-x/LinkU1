import Foundation

public struct User: Codable, Identifiable {
    public let id: Int
    public let email: String
    public let username: String?
    public let avatar: String?
    public let role: String?
    public let createdAt: String?
    
    public enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatar
        case role
        case createdAt = "created_at"
    }
    
    public init(id: Int, email: String, username: String? = nil, avatar: String? = nil, role: String? = nil, createdAt: String? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.avatar = avatar
        self.role = role
        self.createdAt = createdAt
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

struct RegisterResponse: Codable {
    let message: String
    let email: String?
    let verificationRequired: Bool?
    
    enum CodingKeys: String, CodingKey {
        case message, email
        case verificationRequired = "verification_required"
    }
}

