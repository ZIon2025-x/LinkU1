//
//  TasksViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class TasksViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadTasks(category: String? = nil, city: String? = nil, keyword: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "task_type", value: category))
        }
        if let city = city {
            queryItems.append(URLQueryItem(name: "location", value: city))
        }
        if let keyword = keyword {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }
        
        var endpoint = "/api/tasks"
        if !queryItems.isEmpty {
            var components = URLComponents(string: apiService.baseURL + endpoint)!
            components.queryItems = queryItems
            if let query = components.url?.query {
                endpoint = "\(endpoint)?\(query)"
            }
        }
        
        apiService.request(endpoint: endpoint)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.tasks = response.tasks
                }
            )
            .store(in: &cancellables)
    }
}

