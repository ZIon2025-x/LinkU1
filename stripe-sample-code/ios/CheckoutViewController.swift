import UIKit
import StripePaymentSheet
import StripeCore

class CheckoutViewController: UIViewController {
    
    // MARK: - Properties
    
    /// 后端服务器 URL，从环境变量读取，如果没有则使用默认值
    private static let backendURL: URL = {
        if let urlString = ProcessInfo.processInfo.environment["STRIPE_BACKEND_URL"],
           let url = URL(string: urlString) {
            return url
        }
        // 默认值（开发环境）
        return URL(string: "http://127.0.0.1:4242")!
    }()
    
    /// Stripe Publishable Key，从环境变量读取
    private static let stripePublishableKey: String = {
        // 优先从环境变量读取
        if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
            return key
        }
        
        // 如果没有环境变量，尝试从 Info.plist 读取
        if let key = Bundle.main.object(forInfoDictionaryKey: "StripePublishableKey") as? String, !key.isEmpty {
            return key
        }
        
        // 开发环境默认值（仅用于测试，生产环境必须配置环境变量）
        #if DEBUG
        return "pk_test_51SePW98JTHo8ClgaUWRjX9HHabiw09tJQLJlQdJXYCNMVDFr9B9ZeWNwkH9D8NRxreIew4AfQ7hByO6l37KdEkAa00yqY1lz0P"
        #else
        fatalError("STRIPE_PUBLISHABLE_KEY 环境变量未配置！请在 Xcode Scheme 中配置环境变量。")
        #endif
    }()
    
    /// Apple Pay Merchant ID，从环境变量读取
    private static let merchantID: String? = {
        // 优先从环境变量读取
        if let merchantId = ProcessInfo.processInfo.environment["APPLE_PAY_MERCHANT_ID"], !merchantId.isEmpty {
            return merchantId
        }
        
        // 如果没有环境变量，尝试从 Info.plist 读取
        if let merchantId = Bundle.main.object(forInfoDictionaryKey: "ApplePayMerchantID") as? String, !merchantId.isEmpty {
            return merchantId
        }
        
        return nil
    }()
    
    private var paymentIntentClientSecret: String?
    private var paymentSheet: PaymentSheet?
    private var isLoading = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateUI()
            }
        }
    }
    
    // MARK: - UI Components
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Stripe 支付示例"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "点击下方按钮开始支付"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var payButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("立即支付", for: .normal)
        button.setTitle("加载中...", for: .disabled)
        button.backgroundColor = .systemIndigo
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.systemGray, for: .disabled)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.addTarget(self, action: #selector(pay), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupStripe()
        fetchPaymentIntent()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "支付"
        
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(payButton)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            payButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            payButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            payButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            payButton.heightAnchor.constraint(equalToConstant: 56),
            
            activityIndicator.centerXAnchor.constraint(equalTo: payButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: payButton.centerYAnchor)
        ])
    }
    
    private func setupStripe() {
        // 初始化 Stripe
        StripeAPI.defaultPublishableKey = Self.stripePublishableKey
    }
    
    private func updateUI() {
        payButton.isEnabled = !isLoading && paymentIntentClientSecret != nil
        if isLoading {
            activityIndicator.startAnimating()
            payButton.setTitle("", for: .normal)
        } else {
            activityIndicator.stopAnimating()
            payButton.setTitle("立即支付", for: .normal)
        }
    }
    
    // MARK: - Payment Intent
    
    /// 从服务器获取 Payment Intent
    func fetchPaymentIntent() {
        isLoading = true
        
        let url = Self.backendURL.appendingPathComponent("/create-payment-intent")
        
        // 购物车内容，可以根据实际需求修改
        let shoppingCartContent: [String: Any] = [
            "items": [
                ["id": "xl-shirt", "amount": 2000] // amount 以分为单位
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: shoppingCartContent)
        } catch {
            isLoading = false
            displayAlert(title: "错误", message: "无法创建请求: \(error.localizedDescription)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            self.isLoading = false
            
            // 处理网络错误
            if let error = error {
                DispatchQueue.main.async {
                    self.displayAlert(
                        title: "网络错误",
                        message: "无法连接到服务器: \(error.localizedDescription)"
                    )
                }
                return
            }
            
            // 处理 HTTP 响应
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.displayAlert(title: "错误", message: "无效的服务器响应")
                }
                return
            }
            
            // 检查状态码
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.displayAlert(
                        title: "服务器错误",
                        message: "服务器返回错误: HTTP \(httpResponse.statusCode)"
                    )
                }
                return
            }
            
            // 解析 JSON
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                DispatchQueue.main.async {
                    self.displayAlert(title: "解析错误", message: "无法解析服务器响应")
                }
                return
            }
            
            print("✅ PaymentIntent 创建成功")
            self.paymentIntentClientSecret = clientSecret
            
            DispatchQueue.main.async {
                self.payButton.isEnabled = true
            }
        }
        
        task.resume()
    }
    
    // MARK: - Payment
    
    @objc
    func pay() {
        guard let paymentIntentClientSecret = self.paymentIntentClientSecret else {
            displayAlert(title: "错误", message: "支付信息未准备好，请稍后再试")
            return
        }
        
        // 配置 Payment Sheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "示例公司"
        
        // 如果配置了 Merchant ID，启用 Apple Pay
        if let merchantId = Self.merchantID {
            configuration.applePay = .init(
                merchantId: merchantId,
                merchantCountryCode: "GB" // 根据你的业务所在国家修改
            )
        }
        
        // 允许保存支付方式
        configuration.allowsDelayedPaymentMethods = true
        
        // 创建 Payment Sheet
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: paymentIntentClientSecret,
            configuration: configuration
        )
        
        self.paymentSheet = paymentSheet
        
        // 显示支付界面
        paymentSheet.present(from: self) { [weak self] (paymentResult) in
            guard let self = self else { return }
            
            switch paymentResult {
            case .completed:
                print("✅ 支付成功")
                self.displayAlert(
                    title: "支付成功",
                    message: "您的支付已成功完成！"
                ) { [weak self] in
                    // 支付成功后可以刷新 Payment Intent 或返回上一页
                    self?.fetchPaymentIntent()
                }
                
            case .canceled:
                print("ℹ️ 用户取消支付")
                // 用户取消支付，不需要显示错误提示
                
            case .failed(let error):
                print("❌ 支付失败: \(error.localizedDescription)")
                self.displayAlert(
                    title: "支付失败",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    // MARK: - Alert
    
    func displayAlert(title: String, message: String? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alertController = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            
            alertController.addAction(
                UIAlertAction(title: "确定", style: .default) { _ in
                    completion?()
                }
            )
            
            self.present(alertController, animated: true)
        }
    }
}

