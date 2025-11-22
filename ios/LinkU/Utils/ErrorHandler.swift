//
//  ErrorHandler.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    
    static let shared = ErrorHandler()
    
    func handle(_ error: Error) {
        if let apiError = error as? APIError {
            currentError = AppError.api(apiError)
        } else {
            currentError = AppError.unknown(error.localizedDescription)
        }
    }
    
    func clear() {
        currentError = nil
    }
}

enum AppError: LocalizedError {
    case api(APIError)
    case network(String)
    case validation(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .api(let error):
            return error.localizedDescription
        case .network(let message):
            return "网络错误: \(message)"
        case .validation(let message):
            return "验证失败: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

// 错误提示视图修饰符
struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: .constant(errorHandler.currentError != nil)) {
                Button("确定") {
                    errorHandler.clear()
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert() -> some View {
        modifier(ErrorAlert())
    }
}

