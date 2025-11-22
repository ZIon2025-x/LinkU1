//
//  HomeView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showPublishTask = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 欢迎区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("欢迎使用 Link²Ur")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("连接、能力、创造")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 快速操作
                    HStack(spacing: 16) {
                        Button(action: {
                            showPublishTask = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("发布任务")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        NavigationLink(destination: PublishFleaMarketView()) {
                            HStack {
                                Image(systemName: "storefront")
                                Text("发布商品")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    
                    // 推荐任务
                    if !viewModel.featuredTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("推荐任务")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink("查看全部", destination: TasksView())
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.featuredTasks.prefix(5)) { task in
                                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                            FeaturedTaskCard(task: task)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // 最新任务
                    if !viewModel.recentTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("最新任务")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink("查看全部", destination: TasksView())
                            }
                            .padding(.horizontal)
                            
                            ForEach(viewModel.recentTasks.prefix(3)) { task in
                                NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                    TaskRowView(task: task)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("首页")
            .refreshable {
                viewModel.loadData()
            }
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showPublishTask) {
                PublishTaskView()
            }
        }
    }
}

struct FeaturedTaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let firstImage = task.images?.first {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 200, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text(task.title)
                .font(.headline)
                .lineLimit(2)
            
            if let price = task.price {
                Text("£\(price, specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Label(task.city, systemImage: "location")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


#Preview {
    HomeView()
}

