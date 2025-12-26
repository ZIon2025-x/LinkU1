import Foundation
import Combine

// MARK: - APIService Coupons & Points Extension
// Note: Models are defined in Models/CouponPoints.swift

extension APIService {
    
    // MARK: - Points (积分)
    
    /// 获取积分账户信息
    func getPointsAccount() -> AnyPublisher<PointsAccount, APIError> {
        return request(PointsAccount.self, APIEndpoints.Points.account)
    }
    
    /// 获取积分交易记录
    func getPointsTransactions(page: Int = 1, limit: Int = 20) -> AnyPublisher<PointsTransactionListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "limit": "\(limit)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Points.transactions)?\(queryString)"
        return request(PointsTransactionListResponse.self, endpoint)
    }
    
    // MARK: - Coupons (优惠券)
    
    /// 获取可用优惠券列表
    func getAvailableCoupons() -> AnyPublisher<CouponListResponse, APIError> {
        return request(CouponListResponse.self, APIEndpoints.Coupons.available)
    }
    
    /// 获取我的优惠券列表
    func getMyCoupons(status: String? = nil, page: Int = 1, limit: Int = 20) -> AnyPublisher<UserCouponListResponse, APIError> {
        var queryParams: [String: String?] = [
            "page": "\(page)",
            "limit": "\(limit)"
        ]
        if let status = status {
            queryParams["status"] = status
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Coupons.my)?\(queryString)"
        return request(UserCouponListResponse.self, endpoint)
    }
    
    /// 领取优惠券
    func claimCoupon(couponId: Int? = nil, promotionCode: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = CouponClaimRequest(couponId: couponId, promotionCode: promotionCode, idempotencyKey: idempotencyKey)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Coupons.claim, method: "POST", body: bodyDict)
    }
    
    // MARK: - Check In (签到)
    
    /// 每日签到
    func checkIn() -> AnyPublisher<CheckInResponse, APIError> {
        return request(CheckInResponse.self, APIEndpoints.CheckIn.checkIn, method: "POST")
    }
    
    /// 获取签到状态
    func getCheckInStatus() -> AnyPublisher<CheckInStatus, APIError> {
        return request(CheckInStatus.self, APIEndpoints.CheckIn.status)
    }
    
    /// 获取签到奖励配置
    func getCheckInRewards() -> AnyPublisher<CheckInRewardsListResponse, APIError> {
        return request(CheckInRewardsListResponse.self, APIEndpoints.CheckIn.rewards)
    }
    
    // MARK: - Invitation (邀请)
    
    /// 验证邀请码
    func validateInvitationCode(_ code: String) -> AnyPublisher<InvitationCodeValidateResponse, APIError> {
        let body = ["code": code]
        return request(InvitationCodeValidateResponse.self, APIEndpoints.InvitationCodes.validate, method: "POST", body: body)
    }
}

