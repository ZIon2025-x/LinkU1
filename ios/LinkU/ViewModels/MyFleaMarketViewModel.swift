//
//  MyFleaMarketViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class MyFleaMarketViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadMyItems(status: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.getMyFleaMarketItems(status: status)
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

