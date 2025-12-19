import Foundation
import Combine

// MARK: - 学生认证请求模型

struct StudentVerificationSubmitRequest: Encodable {
    let email: String
}

struct StudentVerificationRenewRequest: Encodable {
    let email: String
}

struct StudentVerificationChangeEmailRequest: Encodable {
    let newEmail: String
    
    enum CodingKeys: String, CodingKey {
        case newEmail = "new_email"
    }
}

// MARK: - 学生认证响应模型
// 注意：模型定义已移至 Models/StudentVerification.swift，这里只保留 API 方法

// MARK: - APIService Student Extension

extension APIService {
    
    /// 获取学生认证状态
    func getStudentVerificationStatus() -> AnyPublisher<StudentVerificationStatusResponse, APIError> {
        return request(StudentVerificationStatusResponse.self, "/api/student-verification/status")
    }
    
    /// 提交学生认证申请
    func submitStudentVerification(email: String) -> AnyPublisher<StudentVerificationSubmitResponse, APIError> {
        // 使用 URL 查询参数传递 email (根据后端代码: @router.post("/submit") def submit_verification(..., email: str, ...))
        // 注意：后端定义是 query param 还是 body param 取决于 FastAPI 的默认行为。
        // FastAPI 中如果参数未声明为 Body，默认为 Query param。
        // 查看后端代码: email: str 没有 = Body(...)，所以是 Query param。
        let endpoint = "/api/student-verification/submit?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)"
        return request(StudentVerificationSubmitResponse.self, endpoint, method: "POST")
    }
    
    /// 续期学生认证
    func renewStudentVerification(email: String) -> AnyPublisher<StudentVerificationSubmitResponse, APIError> {
        // 同上，email 是 Query param
        let endpoint = "/api/student-verification/renew?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)"
        return request(StudentVerificationSubmitResponse.self, endpoint, method: "POST")
    }
    
    /// 更换认证邮箱
    func changeStudentVerificationEmail(newEmail: String) -> AnyPublisher<StudentVerificationSubmitResponse, APIError> {
        // 后端参数名为 new_email，且为 Query param
        let endpoint = "/api/student-verification/change-email?new_email=\(newEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? newEmail)"
        return request(StudentVerificationSubmitResponse.self, endpoint, method: "POST")
    }
    
    /// 获取支持的大学列表
    func getUniversities(page: Int = 1, pageSize: Int = 20, search: String? = nil) -> AnyPublisher<UniversityListResponse, APIError> {
        var endpoint = "/api/student-verification/universities?page=\(page)&page_size=\(pageSize)"
        if let search = search {
            endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        return request(UniversityListResponse.self, endpoint)
    }
}

