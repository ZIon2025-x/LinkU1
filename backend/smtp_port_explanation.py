#!/usr/bin/env python3
"""
SMTP端口配置说明
"""

def explain_smtp_ports():
    """解释SMTP端口配置"""
    print("📧 SMTP端口配置说明")
    print("=" * 80)
    print()
    
    print("🔍 常用SMTP端口:")
    print("=" * 50)
    
    print("1️⃣ 端口 587 (推荐)")
    print("   - 名称: 提交端口 (Submission Port)")
    print("   - 用途: 客户端向邮件服务器发送邮件")
    print("   - 加密: 支持STARTTLS (TLS加密)")
    print("   - 安全: 高安全性")
    print("   - 兼容性: 大多数邮件服务商支持")
    print("   - 防火墙: 通常允许通过")
    print("   - 推荐指数: ⭐⭐⭐⭐⭐")
    print()
    
    print("2️⃣ 端口 465 (传统)")
    print("   - 名称: SMTPS端口")
    print("   - 用途: SSL/TLS加密的SMTP")
    print("   - 加密: 全程SSL加密")
    print("   - 安全: 高安全性")
    print("   - 兼容性: 大多数邮件服务商支持")
    print("   - 防火墙: 通常允许通过")
    print("   - 推荐指数: ⭐⭐⭐⭐")
    print()
    
    print("3️⃣ 端口 25 (不推荐)")
    print("   - 名称: 标准SMTP端口")
    print("   - 用途: 邮件服务器间通信")
    print("   - 加密: 通常不加密")
    print("   - 安全: 低安全性")
    print("   - 兼容性: 被大多数ISP阻止")
    print("   - 防火墙: 经常被阻止")
    print("   - 推荐指数: ⭐")
    print()
    
    print("🎯 为什么选择587端口？")
    print("=" * 50)
    print("1. Gmail官方推荐")
    print("   - Gmail官方文档明确推荐使用587端口")
    print("   - 支持STARTTLS加密")
    print("   - 更稳定可靠")
    print()
    print("2. 安全性更高")
    print("   - 支持TLS加密传输")
    print("   - 防止邮件内容被窃听")
    print("   - 符合现代安全标准")
    print()
    print("3. 兼容性更好")
    print("   - 大多数邮件服务商支持")
    print("   - 防火墙通常允许通过")
    print("   - 网络环境适应性更强")
    print()
    print("4. 标准协议")
    print("   - RFC 6409标准定义")
    print("   - 专门用于邮件提交")
    print("   - 业界广泛采用")
    print()
    
    print("🔧 不同邮件服务商的端口配置:")
    print("=" * 50)
    print("Gmail:")
    print("  - 端口: 587 (推荐) 或 465")
    print("  - 加密: STARTTLS (587) 或 SSL (465)")
    print("  - 服务器: smtp.gmail.com")
    print()
    print("Outlook/Hotmail:")
    print("  - 端口: 587 (推荐) 或 465")
    print("  - 加密: STARTTLS (587) 或 SSL (465)")
    print("  - 服务器: smtp-mail.outlook.com")
    print()
    print("Yahoo:")
    print("  - 端口: 587 (推荐) 或 465")
    print("  - 加密: STARTTLS (587) 或 SSL (465)")
    print("  - 服务器: smtp.mail.yahoo.com")
    print()
    print("企业邮箱:")
    print("  - 端口: 587 (推荐) 或 465")
    print("  - 加密: STARTTLS (587) 或 SSL (465)")
    print("  - 服务器: 根据企业配置")
    print()
    
    print("⚠️  端口选择注意事项:")
    print("=" * 50)
    print("1. 端口587 + STARTTLS:")
    print("   - 优点: 标准、安全、兼容性好")
    print("   - 缺点: 需要额外的TLS握手")
    print("   - 适用: 大多数情况")
    print()
    print("2. 端口465 + SSL:")
    print("   - 优点: 全程加密、简单")
    print("   - 缺点: 非标准端口、兼容性稍差")
    print("   - 适用: 特殊网络环境")
    print()
    print("3. 端口25:")
    print("   - 优点: 标准端口")
    print("   - 缺点: 通常被阻止、不安全")
    print("   - 适用: 不推荐使用")
    print()
    
    print("🔍 如何测试端口连接？")
    print("=" * 50)
    print("1. 使用telnet测试:")
    print("   telnet smtp.gmail.com 587")
    print("   telnet smtp.gmail.com 465")
    print()
    print("2. 使用Python测试:")
    print("   import smtplib")
    print("   server = smtplib.SMTP('smtp.gmail.com', 587)")
    print("   server.starttls()")
    print()
    print("3. 使用在线工具:")
    print("   - 端口扫描工具")
    print("   - SMTP连接测试工具")
    print()
    
    print("📋 推荐配置:")
    print("=" * 50)
    print("对于Gmail:")
    print("  SMTP_SERVER=smtp.gmail.com")
    print("  SMTP_PORT=587")
    print("  SMTP_USE_TLS=true")
    print("  SMTP_USE_SSL=false")
    print()
    print("对于其他邮件服务商:")
    print("  SMTP_SERVER=your-smtp-server.com")
    print("  SMTP_PORT=587")
    print("  SMTP_USE_TLS=true")
    print("  SMTP_USE_SSL=false")
    print()
    
    print("🎯 总结:")
    print("=" * 50)
    print("端口587是SMTP的标准提交端口，具有以下优势:")
    print("1. 官方推荐 - Gmail等主要邮件服务商推荐")
    print("2. 安全性高 - 支持TLS加密")
    print("3. 兼容性好 - 大多数网络环境支持")
    print("4. 标准协议 - 符合RFC标准")
    print("5. 稳定性强 - 连接更稳定可靠")
    print()
    print("因此，选择587端口是最佳实践！")

def test_smtp_ports():
    """测试SMTP端口连接"""
    print("\n🔧 测试SMTP端口连接")
    print("=" * 80)
    
    import smtplib
    
    # 测试Gmail的587端口
    print("测试Gmail 587端口:")
    try:
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        print("✅ 端口587连接成功")
        server.quit()
    except Exception as e:
        print(f"❌ 端口587连接失败: {e}")
    
    print()
    
    # 测试Gmail的465端口
    print("测试Gmail 465端口:")
    try:
        server = smtplib.SMTP_SSL('smtp.gmail.com', 465)
        print("✅ 端口465连接成功")
        server.quit()
    except Exception as e:
        print(f"❌ 端口465连接失败: {e}")
    
    print()
    
    # 测试Gmail的25端口
    print("测试Gmail 25端口:")
    try:
        server = smtplib.SMTP('smtp.gmail.com', 25)
        print("✅ 端口25连接成功")
        server.quit()
    except Exception as e:
        print(f"❌ 端口25连接失败: {e}")

def main():
    """主函数"""
    print("🚀 SMTP端口配置详解")
    print("=" * 80)
    
    # 解释SMTP端口
    explain_smtp_ports()
    
    # 测试SMTP端口连接
    test_smtp_ports()
    
    print("\n📋 总结:")
    print("SMTP端口587是最佳选择，因为它安全、标准、兼容性好！")
    print("=" * 80)

if __name__ == "__main__":
    main()
