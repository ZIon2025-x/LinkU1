import Foundation
import Combine

// MARK: - APIService Coupons & Points Extension
// Note: Models are defined in Models/CouponPoints.swift

extension APIService {
    
    // MARK: - Points (积分)
    
    /// 获取积分账户信息
    func getPointsAccount() -> AnyPublisher<PointsAccount, APIError> {
        return request(PointsAccount.self, "/api/points/account")
    }
    
    /// 获取积分交易记录
    func getPointsTransactions(page: Int = 1, limit: Int = 20) -> AnyPublisher<PointsTransactionListResponse, APIError> {
        return request(PointsTransactionListResponse.self, "/api/points/transactions?page=\(page)&limit=\(limit)")
    }
    
    // MARK: - Coupons (优惠券)
    
    /// 获取可用优惠券列表
    func getAvailableCoupons() -> AnyPublisher<CouponListResponse, APIError> {
        return request(CouponListResponse.self, "/api/coupons/available")
    }
    
    /// 获取我的优惠券列表
    func getMyCoupons(status: String? = nil, page: Int = 1, limit: Int = 20) -> AnyPublisher<UserCouponListResponse, APIError> {
        var endpoint = "/api/coupons/my?page=\(page)&limit=\(limit)"
        if let status = status {
            endpoint += "&status=\(status)"
        }
        return request(UserCouponListResponse.self, endpoint)
    }
    
    /// 领取优惠券
    func claimCoupon(couponId: Int? = nil, promotionCode: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = CouponClaimRequest(couponId: couponId, promotionCode: promotionCode, idempotencyKey: idempotencyKey)
        
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, "/api/coupons/claim", method: "POST", body: bodyDict)
    }
    
    // MARK: - Check In (签到)
    
    /// 每日签到
    func checkIn() -> AnyPublisher<CheckInResponse, APIError> {
        return request(CheckInResponse.self, "/api/checkin", method: "POST")
    }
    
    /// 获取签到状态
    func getCheckInStatus() -> AnyPublisher<CheckInStatus, APIError> {
        return request(CheckInStatus.self, "/api/checkin/status")
    }
    
    /// 获取签到奖励配置
    func getCheckInRewards() -> AnyPublisher<CheckInRewardsListResponse, APIError> {
        return request(CheckInRewardsListResponse.self, "/api/checkin/rewards")
    }
    
    // MARK: - Invitation (邀请)
    
    /// 验证邀请码
    func validateInvitationCode(_ code: String) -> AnyPublisher<InvitationCodeValidateResponse, APIError> {
        let body = ["code": code]
        return request(InvitationCodeValidateResponse.self, "/api/invitation-codes/validate", method: "POST", body: body)
    }
}

