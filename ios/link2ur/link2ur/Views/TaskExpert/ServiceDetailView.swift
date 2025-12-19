import SwiftUI

struct ServiceDetailView: View {
    let serviceId: Int
    @StateObject private var viewModel = ServiceDetailViewModel()
    @State private var showApplySheet = false
    @State private var applicationMessage = ""
    @State private var counterPrice: Double?
    @State private var showCounterPrice = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.service == nil {
                ProgressView()
            } else if let service = viewModel.service {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 服务图片
                        if let images = service.images, !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(images, id: \.self) { imageUrl in
                                        AsyncImage(url: imageUrl.toImageURL()) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(AppColors.primaryLight)
                                        }
                                        .frame(width: 300, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        
                        // 服务信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(service.serviceName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack {
                                Text("¥ \(String(format: "%.2f", service.basePrice))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.error)
                                
                                Text(service.currency)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            if let description = service.description {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if service.hasTimeSlots == true {
                                Divider()
                                
                                Text("可选时间段")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if viewModel.timeSlots.isEmpty {
                                    Text("暂无可用时间段")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                } else {
                                    ForEach(viewModel.timeSlots) { slot in
                                        TimeSlotCard(slot: slot)
                                    }
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 申请按钮
                        Button(action: {
                            showApplySheet = true
                        }) {
                            Text("申请服务")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showApplySheet) {
            ApplyServiceSheet(
                message: $applicationMessage,
                counterPrice: $counterPrice,
                showCounterPrice: $showCounterPrice,
                onApply: {
                    viewModel.applyService(serviceId: serviceId, message: applicationMessage.isEmpty ? nil : applicationMessage, counterPrice: counterPrice) { success in
                        if success {
                            showApplySheet = false
                            applicationMessage = ""
                            counterPrice = nil
                        }
                    }
                }
            )
        }
        .onAppear {
            viewModel.loadService(serviceId: serviceId)
            if viewModel.service?.hasTimeSlots == true {
                viewModel.loadTimeSlots(serviceId: serviceId)
            }
        }
    }
}

// 时间段卡片
struct TimeSlotCard: View {
    let slot: ServiceTimeSlot
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDateTime(slot.slotStartDatetime))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(slot.currentParticipants)/\(slot.maxParticipants) 人")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            if slot.isAvailable {
                Text("可选")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.success)
                    .cornerRadius(AppCornerRadius.small)
            } else {
                Text("已满")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.textSecondary)
                    .cornerRadius(AppCornerRadius.small)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.primaryLight)
        .cornerRadius(AppCornerRadius.small)
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        return DateFormatterHelper.shared.formatFullTime(dateString)
    }
}

// 申请服务弹窗
struct ApplyServiceSheet: View {
    @Binding var message: String
    @Binding var counterPrice: Double?
    @Binding var showCounterPrice: Bool
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                // 申请留言
                VStack(alignment: .leading, spacing: 8) {
                    Text("申请留言")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextEditor(text: $message)
                        .frame(height: 100)
                        .padding(8)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // 议价选项
                Toggle("是否议价", isOn: $showCounterPrice)
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                
                if showCounterPrice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("议价金额")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入金额", value: $counterPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                Spacer()
                
                // 提交按钮
                Button(action: onApply) {
                    Text("提交申请")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                }
            }
            .padding(AppSpacing.md)
            .navigationTitle("申请服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

