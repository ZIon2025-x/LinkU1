import Foundation
import Combine

// MARK: - APIService Official Activities Extension

extension APIService {

    /// Apply to an official activity (lottery / first-come-first-served)
    func applyToOfficialActivity(activityId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(
            EmptyResponse.self,
            "/api/official-activities/\(activityId)/apply",
            method: "POST"
        )
    }

    /// Cancel an official activity application
    func cancelOfficialActivityApplication(activityId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(
            EmptyResponse.self,
            "/api/official-activities/\(activityId)/apply",
            method: "DELETE"
        )
    }

    /// Get official activity result (winners, my application status, etc.)
    func getOfficialActivityResult(activityId: Int) -> AnyPublisher<OfficialActivityResult, APIError> {
        return request(
            OfficialActivityResult.self,
            "/api/official-activities/\(activityId)/result"
        )
    }
}
