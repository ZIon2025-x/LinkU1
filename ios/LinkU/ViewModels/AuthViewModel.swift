//
//  AuthViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        // 检查本地存储的token
        if let token = KeychainHelper.shared.getToken() {
            // 验证token有效性
            validateToken(token)
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        let request = LoginRequest(email: email, password: password)
        apiService.login(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // 保存token
                    KeychainHelper.shared.saveToken(response.accessToken)
                    self?.currentUser = response.user
                    self?.isAuthenticated = true
                    
                    // 保存userId用于WebSocket重连
                    UserDefaults.standard.set("\(response.user.id)", forKey: "currentUserId")
                    
                    // 连接WebSocket
                    WebSocketService.shared.connect(userId: "\(response.user.id)")
                }
            )
            .store(in: &cancellables)
    }
    
    func register(username: String, email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        let request = RegisterRequest(username: username, email: email, password: password)
        apiService.register(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    KeychainHelper.shared.saveToken(response.accessToken)
                    self?.currentUser = response.user
                    self?.isAuthenticated = true
                }
            )
            .store(in: &cancellables)
    }
    
    func logout() {
        KeychainHelper.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        currentUser = nil
        isAuthenticated = false
        WebSocketService.shared.disconnect()
    }
    
    private func validateToken(_ token: String) {
        // TODO: 实现token验证逻辑
        // 如果token有效，设置isAuthenticated = true
    }
}

