//
//  FleaMarketViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class FleaMarketViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadCategories() {
        apiService.getFleaMarketCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] response in
                    self?.categories = response.categories
                }
            )
            .store(in: &cancellables)
    }
    
    func loadItems(category: String? = nil, keyword: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.getFleaMarketItems(category: category, keyword: keyword)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.items = response.items
                }
            )
            .store(in: &cancellables)
    }
}

