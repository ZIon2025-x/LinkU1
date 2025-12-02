import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let username: String?
    let avatar: String?
    let role: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatar
        case role
        case createdAt = "created_at"
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

