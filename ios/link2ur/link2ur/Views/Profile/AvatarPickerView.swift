import SwiftUI
import Combine

struct AvatarPickerView: View {
    @Binding var selectedAvatar: String
    let currentAvatar: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AvatarPickerViewModel()
    
    private let avatars = ["avatar1", "avatar2", "avatar3", "avatar4"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.lg) {
                    Text("选择头像")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, AppSpacing.xl)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ], spacing: AppSpacing.lg) {
                        ForEach(avatars, id: \.self) { avatarName in
                            Button {
                                let avatarPath = "/static/\(avatarName).png"
                                selectedAvatar = avatarPath
                                viewModel.updateAvatar(avatar: avatarPath) {
                                    dismiss()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 100, height: 100)
                                        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
                                    
                                    Image(avatarName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                    
                                    if selectedAvatar == "/static/\(avatarName).png" || currentAvatar == "/static/\(avatarName).png" {
                                        Circle()
                                            .stroke(AppColors.primary, lineWidth: 4)
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.primary)
                                            .font(.system(size: 28))
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .offset(x: 35, y: -35)
                                    }
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

@MainActor
class AvatarPickerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func updateAvatar(avatar: String, completion: @escaping () -> Void) {
        isLoading = true
        errorMessage = nil
        
        apiService.updateAvatar(avatar: avatar)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        self?.errorMessage = error.userFriendlyMessage
                    } else {
                        // 刷新用户信息
                        NotificationCenter.default.post(name: .userDidLogin, object: nil)
                        completion()
                    }
                },
                receiveValue: { [weak self] updatedUser in
                    self?.isLoading = false
                    // 刷新用户信息
                    NotificationCenter.default.post(name: .userDidLogin, object: nil)
                    completion()
                }
            )
            .store(in: &cancellables)
    }
}

