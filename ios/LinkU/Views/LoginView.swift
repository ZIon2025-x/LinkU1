//
//  LoginView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Logo区域
            VStack(spacing: 16) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Link²Ur")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("连接、能力、创造")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // 登录表单
            VStack(spacing: 16) {
                TextField("邮箱", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                SecureField("密码", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    authViewModel.login(email: email, password: password)
                }) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("登录")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .controlSize(.large)
                
                Button("还没有账号？注册") {
                    showRegister = true
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

