//
//  ProfileView.swift
//  LinkU
//
//  Created on 2025-01-20.
//  用户端个人中心 - 不包含客服和管理员功能
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showMyTasks = false
    @State private var showMyFleaMarket = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                if let user = authViewModel.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 我的内容
                Section("我的内容") {
                    NavigationLink(destination: MyTasksView()) {
                        Label("我的任务", systemImage: "list.bullet.rectangle")
                    }
                    
                    NavigationLink(destination: MyFleaMarketView()) {
                        Label("我的发布", systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: WalletView()) {
                        Label("我的钱包", systemImage: "creditcard")
                    }
                }
                
                // 设置
                Section("设置") {
                    NavigationLink(destination: SettingsView()) {
                        Label("设置", systemImage: "gearshape")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("关于", systemImage: "info.circle")
                    }
                }
                
                // 退出登录
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}

// 我的任务视图
struct MyTasksView: View {
    @StateObject private var viewModel = MyTasksViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.tasks) { task in
                TaskRowView(task: task)
            }
        }
        .navigationTitle("我的任务")
        .onAppear {
            viewModel.loadMyTasks()
        }
    }
}

// 我的跳蚤市场视图
struct MyFleaMarketView: View {
    @StateObject private var viewModel = MyFleaMarketViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                FleaMarketItemRowView(item: item)
            }
        }
        .navigationTitle("我的发布")
        .onAppear {
            viewModel.loadMyItems()
        }
    }
}

// 钱包视图
struct WalletView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("钱包功能")
                .font(.title2)
            Text("即将推出")
                .foregroundColor(.secondary)
        }
        .navigationTitle("我的钱包")
    }
}

// 设置视图
struct SettingsView: View {
    @AppStorage("language") private var language = "zh"
    
    var body: some View {
        Form {
            Section("语言设置") {
                Picker("语言", selection: $language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
            }
            
            Section("通知设置") {
                Toggle("推送通知", isOn: .constant(true))
                Toggle("消息提醒", isOn: .constant(true))
            }
        }
        .navigationTitle("设置")
    }
}

// 关于视图
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("LinkU")
                .font(.title)
                .fontWeight(.bold)
            
            Text("版本 1.0.0")
                .foregroundColor(.secondary)
            
            Text("连接、能力、创造")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("关于")
    }
}

// 占位视图组件
struct FleaMarketItemRowView: View {
    let item: FleaMarketItem
    
    var body: some View {
        HStack {
            if let firstImage = item.images.first {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                Text("£\(item.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}


#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

