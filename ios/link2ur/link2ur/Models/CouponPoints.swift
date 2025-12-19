import Foundation

// MARK: - Points (积分)

struct PointsAccount: Codable {
    let balance: Int
    let balanceDisplay: String
    let currency: String
    let totalEarned: Int
    let totalSpent: Int
    let usageRestrictions: UsageRestrictions
    
    enum CodingKeys: String, CodingKey {
        case balance
        case balanceDisplay = "balance_display"
        case currency
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
        case usageRestrictions = "usage_restrictions"
    }
}

struct UsageRestrictions: Codable {
    let allowed: [String]
    let forbidden: [String]
}

struct PointsTransaction: Codable, Identifiable {
    let id: Int
    let type: String
    let amount: Int
    let amountDisplay: String
    let balanceAfter: Int
    let balanceAfterDisplay: String
    let currency: String
    let source: String?
    let description: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, amount
        case amountDisplay = "amount_display"
        case balanceAfter = "balance_after"
        case balanceAfterDisplay = "balance_after_display"
        case currency, source, description
        case createdAt = "created_at"
    }
}

struct PointsTransactionListResponse: Codable {
    let total: Int
    let page: Int
    let limit: Int
    let data: [PointsTransaction]
}

// MARK: - Coupon (优惠券)

struct Coupon: Codable, Identifiable {
    let id: Int
    let code: String
    let name: String
    let type: String
    let discountValue: Int
    let discountValueDisplay: String
    let minAmount: Int
    let minAmountDisplay: String
    let currency: String
    let validUntil: String
    
    enum CodingKeys: String, CodingKey {
        case id, code, name, type
        case discountValue = "discount_value"
        case discountValueDisplay = "discount_value_display"
        case minAmount = "min_amount"
        case minAmountDisplay = "min_amount_display"
        case currency
        case validUntil = "valid_until"
    }
}

struct CouponListResponse: Codable {
    let data: [Coupon]
}

struct UserCoupon: Codable, Identifiable {
    let id: Int
    let coupon: Coupon
    let status: String
    let obtainedAt: String
    let validUntil: String
    
    enum CodingKeys: String, CodingKey {
        case id, coupon, status
        case obtainedAt = "obtained_at"
        case validUntil = "valid_until"
    }
}

struct UserCouponListResponse: Codable {
    let data: [UserCoupon]
}

struct CouponClaimRequest: Encodable {
    let couponId: Int?
    let promotionCode: String?
    let idempotencyKey: String?
    
    enum CodingKeys: String, CodingKey {
        case couponId = "coupon_id"
        case promotionCode = "promotion_code"
        case idempotencyKey = "idempotency_key"
    }
}

// MARK: - Check In (签到)

struct CheckInResponse: Codable {
    let success: Bool
    let checkInDate: String
    let consecutiveDays: Int
    let reward: CheckInReward?
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case checkInDate = "check_in_date"
        case consecutiveDays = "consecutive_days"
        case reward, message
    }
}

struct CheckInReward: Codable {
    let type: String
    let pointsReward: Int?
    let pointsRewardDisplay: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case pointsReward = "points_reward"
        case pointsRewardDisplay = "points_reward_display"
        case description
    }
}

struct CheckInStatus: Codable {
    let todayChecked: Bool
    let consecutiveDays: Int
    let lastCheckInDate: String?
    let nextCheckInDate: String?
    
    enum CodingKeys: String, CodingKey {
        case todayChecked = "today_checked"
        case consecutiveDays = "consecutive_days"
        case lastCheckInDate = "last_check_in_date"
        case nextCheckInDate = "next_check_in_date"
    }
}

struct CheckInRewardConfig: Codable {
    let consecutiveDays: Int
    let rewardType: String
    let description: String
    let pointsReward: Int?
    let pointsRewardDisplay: String?
    
    enum CodingKeys: String, CodingKey {
        case consecutiveDays = "consecutive_days"
        case rewardType = "reward_type"
        case description
        case pointsReward = "points_reward"
        case pointsRewardDisplay = "points_reward_display"
    }
}

struct CheckInRewardsListResponse: Codable {
    let rewards: [CheckInRewardConfig]
}

// MARK: - Invitation (邀请)

struct InvitationCodeValidateResponse: Codable {
    let valid: Bool
    let code: String
    let name: String
    let rewardType: String
    let pointsReward: Int
    let pointsRewardDisplay: String
    let coupon: InvitationCoupon?
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case valid, code, name
        case rewardType = "reward_type"
        case pointsReward = "points_reward"
        case pointsRewardDisplay = "points_reward_display"
        case coupon, message
    }
}

struct InvitationCoupon: Codable {
    let id: Int
    let name: String
}

