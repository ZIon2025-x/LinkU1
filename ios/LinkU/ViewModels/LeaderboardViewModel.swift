import Foundation
import Combine

class LeaderboardViewModel: ObservableObject {
    @Published var leaderboards: [CustomLeaderboard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadLeaderboards(location: String? = nil, sort: String = "latest") {
        isLoading = true
        var endpoint = "/api/custom-leaderboards?status=active&sort=\(sort)&limit=20"
        if let location = location {
            endpoint += "&location=\(location)"
        }
        
        apiService.request(CustomLeaderboardListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.leaderboards = response.items
            })
            .store(in: &cancellables)
    }
}

class LeaderboardDetailViewModel: ObservableObject {
    @Published var leaderboard: CustomLeaderboard?
    @Published var items: [LeaderboardItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadLeaderboard(leaderboardId: Int) {
        isLoading = true
        apiService.request(CustomLeaderboard.self, "/api/custom-leaderboards/\(leaderboardId)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] leaderboard in
                self?.leaderboard = leaderboard
            })
            .store(in: &cancellables)
    }
    
    func loadItems(leaderboardId: Int, sort: String = "vote_score") {
        let endpoint = "/api/custom-leaderboards/\(leaderboardId)/items?sort=\(sort)&limit=50"
        apiService.request(LeaderboardItemListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.items = response.items
            })
            .store(in: &cancellables)
    }
    
    func voteItem(itemId: Int, voteType: String, completion: @escaping (Bool, Int, Int, Int) -> Void) {
        // 投票API使用query参数
        let endpoint = "/api/custom-leaderboards/items/\(itemId)/vote?vote_type=\(voteType)"
        apiService.request(VoteResponse.self, endpoint, method: "POST", body: [:])
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(true, response.upvotes, response.downvotes, response.netVotes)
            })
            .store(in: &cancellables)
    }
    
    func submitItem(leaderboardId: Int, name: String, description: String?, address: String?, phone: String?, website: String?, images: [String]?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "leaderboard_id": leaderboardId,
            "name": name
        ]
        
        if let description = description {
            body["description"] = description
        }
        if let address = address {
            body["address"] = address
        }
        if let phone = phone {
            body["phone"] = phone
        }
        if let website = website {
            body["website"] = website
        }
        if let images = images {
            body["images"] = images
        }
        
        apiService.request(LeaderboardItem.self, "/api/custom-leaderboards/items", method: "POST", body: body)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    completion(false)
                }
            }, receiveValue: { [weak self] item in
                // 重新加载列表
                self?.loadItems(leaderboardId: leaderboardId)
                completion(true)
            })
            .store(in: &cancellables)
    }
}

