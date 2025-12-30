import SwiftUI
import StripePaymentSheet

struct StripePaymentView: View {
    let taskId: Int
    let amount: Double
    
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    @State private var presentingPaymentSheet = false
    
    init(taskId: Int, amount: Double) {
        self.taskId = taskId
        self.amount = amount
        _viewModel = StateObject(wrappedValue: PaymentViewModel(taskId: taskId, amount: amount))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("正在加载支付表单...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.paymentSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("支付成功！")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("任务已成功支付，正在更新状态...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        // 等待后端 webhook 处理完成（通常需要 1-2 秒）
                        // 然后关闭支付界面，让父视图刷新任务状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("支付错误")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重试") {
                            viewModel.createPaymentIntent()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.paymentSheet != nil {
                    VStack(spacing: 20) {
                        Text("支付金额")
                            .font(.headline)
                        Text("£\(String(format: "%.2f", amount))")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Button("继续支付") {
                            presentingPaymentSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .sheet(isPresented: $presentingPaymentSheet) {
                        if let paymentSheet = viewModel.paymentSheet {
                            PaymentSheetViewController(
                                paymentSheet: paymentSheet,
                                onResult: { result in
                                    viewModel.handlePaymentResult(result)
                                    presentingPaymentSheet = false
                                }
                            )
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("准备支付...")
                            .font(.headline)
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .navigationTitle("支付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.createPaymentIntent()
            }
        }
    }
}

// Payment Sheet UIViewController 包装器
struct PaymentSheetViewController: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onResult: (PaymentSheetResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        
        DispatchQueue.main.async {
            paymentSheet.present(from: vc) { result in
                onResult(result)
            }
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

