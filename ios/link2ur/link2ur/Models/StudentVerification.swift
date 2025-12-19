import Foundation

// MARK: - Student Verification (学生认证)

struct StudentVerificationStatus: Codable {
    let status: String
    let email: String?
    let university: String?
    let submittedAt: String?
    let verifiedAt: String?
    let rejectionReason: String?
    
    enum CodingKeys: String, CodingKey {
        case status, email, university
        case submittedAt = "submitted_at"
        case verifiedAt = "verified_at"
        case rejectionReason = "rejection_reason"
    }
}

struct StudentVerificationStatusData: Codable {
    let isVerified: Bool
    let status: String?
    let university: UniversityInfo?
    let email: String?
    let verifiedAt: String?
    let expiresAt: String?
    let daysRemaining: Int?
    let canRenew: Bool?
    let renewableFrom: String?
    let emailLocked: Bool?
    let tokenExpired: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isVerified = "is_verified"
        case status
        case university
        case email
        case verifiedAt = "verified_at"
        case expiresAt = "expires_at"
        case daysRemaining = "days_remaining"
        case canRenew = "can_renew"
        case renewableFrom = "renewable_from"
        case emailLocked = "email_locked"
        case tokenExpired = "token_expired"
    }
}

struct StudentVerificationStatusResponse: Codable {
    let code: Int
    let data: StudentVerificationStatusData
}

struct StudentVerificationSubmitData: Codable {
    let verificationId: Int
    let email: String
    let university: UniversityInfo
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case verificationId = "verification_id"
        case email
        case university
        case expiresAt = "expires_at"
    }
}

struct StudentVerificationSubmitResponse: Codable {
    let code: Int
    let message: String
    let data: StudentVerificationSubmitData?
}

struct StudentVerificationRenewResponse: Codable {
    let code: Int
    let message: String
}

struct StudentVerificationChangeEmailResponse: Codable {
    let code: Int
    let message: String
}

struct UniversityInfo: Codable, Identifiable {
    let id: Int
    let name: String
    let nameCn: String?
    let emailDomain: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case nameCn = "name_cn"
        case emailDomain = "email_domain"
    }
}

struct University: Codable, Identifiable {
    let id: Int
    let name: String
    let domain: String
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, domain, country
    }
}

struct UniversityListData: Codable {
    let total: Int
    let page: Int
    let pageSize: Int
    let items: [UniversityInfo]
    
    enum CodingKeys: String, CodingKey {
        case total, page
        case pageSize = "page_size"
        case items
    }
}

struct UniversityListResponse: Codable {
    let code: Int
    let data: UniversityListData
}

struct UniversitiesResponse: Codable {
    let code: Int
    let data: [University]
}
