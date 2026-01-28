import SwiftUI

/// 支付倒计时视图组件
struct PaymentCountdownView: View {
    let expiresAt: String?  // ISO 格式的过期时间字符串
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    private var formattedTime: String {
        if isExpired {
            return "0:00"
        }
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        if let expiresAt = expiresAt, !expiresAt.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isExpired ? AppColors.error : AppColors.warning)
                
                if isExpired {
                    Text(LocalizationKey.paymentCountdownExpired.localized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.error)
                } else {
                    Text(LocalizationKey.paymentCountdownRemaining.localized(argument: formattedTime))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.warning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isExpired ? AppColors.error.opacity(0.1) : AppColors.warning.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isExpired ? AppColors.error.opacity(0.3) : AppColors.warning.opacity(0.3), lineWidth: 1)
            )
            .onAppear {
                updateTimeRemaining()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private func updateTimeRemaining() {
        guard let expiresAt = expiresAt, !expiresAt.isEmpty else {
            timeRemaining = 0
            return
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let expiryDate = formatter.date(from: expiresAt) else {
            // 尝试不带毫秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            guard let expiryDateFallback = formatter.date(from: expiresAt) else {
                timeRemaining = 0
                return
            }
            timeRemaining = max(0, expiryDateFallback.timeIntervalSinceNow)
            return
        }
        
        timeRemaining = max(0, expiryDate.timeIntervalSinceNow)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
            if timeRemaining <= 0 {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 支付倒计时横幅（用于支付页面顶部）
struct PaymentCountdownBanner: View {
    let expiresAt: String?
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    private var formattedTime: String {
        if isExpired {
            return "0:00"
        }
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        if let expiresAt = expiresAt, !expiresAt.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isExpired ? AppColors.error : AppColors.warning)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isExpired ? LocalizationKey.paymentCountdownBannerExpired.localized : LocalizationKey.paymentCountdownBannerTitle.localized)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(isExpired ? AppColors.error : AppColors.warning)
                    
                    if !isExpired {
                        Text(LocalizationKey.paymentCountdownBannerSubtitle.localized(argument: formattedTime))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                if !isExpired {
                    Text(formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.warning)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isExpired ? AppColors.error.opacity(0.1) : AppColors.warning.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isExpired ? AppColors.error.opacity(0.3) : AppColors.warning.opacity(0.3), lineWidth: 1.5)
            )
            .onAppear {
                updateTimeRemaining()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private func updateTimeRemaining() {
        guard let expiresAt = expiresAt, !expiresAt.isEmpty else {
            timeRemaining = 0
            return
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let expiryDate = formatter.date(from: expiresAt) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let expiryDateFallback = formatter.date(from: expiresAt) else {
                timeRemaining = 0
                return
            }
            timeRemaining = max(0, expiryDateFallback.timeIntervalSinceNow)
            return
        }
        
        timeRemaining = max(0, expiryDate.timeIntervalSinceNow)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
            if timeRemaining <= 0 {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
