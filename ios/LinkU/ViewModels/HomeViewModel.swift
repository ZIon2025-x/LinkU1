//
//  HomeViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var featuredTasks: [Task] = []
    @Published var recentTasks: [Task] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadData() {
        isLoading = true
        
        // 加载推荐任务
        let params = TaskListParams(category: nil, city: nil)
        apiService.getTasks(params: params)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] response in
                    self?.featuredTasks = Array(response.tasks.prefix(10))
                    self?.recentTasks = response.tasks
                }
            )
            .store(in: &cancellables)
    }
}

