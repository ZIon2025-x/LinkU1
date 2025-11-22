//
//  FleaMarketView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct FleaMarketView: View {
    @StateObject private var viewModel = FleaMarketViewModel()
    @State private var selectedCategory: String?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryChip(title: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                            viewModel.loadItems(category: nil, keyword: searchText.isEmpty ? nil : searchText)
                        }
                        
                        ForEach(viewModel.categories, id: \.self) { category in
                            CategoryChip(title: category, isSelected: selectedCategory == category) {
                                selectedCategory = category
                                viewModel.loadItems(category: category, keyword: searchText.isEmpty ? nil : searchText)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // 商品列表
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.items) { item in
                                FleaMarketItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("跳蚤市场")
            .onAppear {
                viewModel.loadCategories()
                viewModel.loadItems()
            }
            .onChange(of: searchText) { newValue in
                viewModel.loadItems(category: selectedCategory, keyword: newValue.isEmpty ? nil : newValue)
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

struct FleaMarketItemCard: View {
    let item: FleaMarketItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图片
            if let firstImage = item.images.first {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // 标题
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
            
            // 价格
            Text("£\(item.price, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // 位置
            Label(item.city, systemImage: "location")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索商品...", text: $text)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

class FleaMarketViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadCategories() {
        // TODO: 实现获取分类列表的API
        // apiService.getFleaMarketCategories()
    }
    
    func loadItems(category: String? = nil, keyword: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        // TODO: 实现获取商品列表的API
        // apiService.getFleaMarketItems(category: category, keyword: keyword)
    }
}

#Preview {
    FleaMarketView()
}
