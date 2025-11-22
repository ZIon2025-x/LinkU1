//
//  AppState.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var selectedLanguage: String = "zh"
    @Published var isLoading: Bool = false
    
    // 可以添加更多全局状态
}

