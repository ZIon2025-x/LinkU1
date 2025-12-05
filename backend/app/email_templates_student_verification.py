"""
学生认证邮件模板
"""

from app.email_templates import get_email_header


def get_student_verification_email(language: str, verification_url: str, university_name: str = None) -> tuple[str, str]:
    """学生认证验证邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 学生身份验证"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    学生身份验证
                </h2>
                <p>您好，</p>
                <p>感谢您使用 Link²Ur 平台！请点击下面的链接验证您的学生邮箱：</p>
                {f'<p><strong>大学：</strong>{university_name}</p>' if university_name else ''}
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{verification_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        验证学生邮箱
                    </a>
                </div>
                
                <p>或者复制以下链接到浏览器中打开：</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{verification_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>注意：</strong>此链接15分钟内有效，请及时验证。
                </p>
                <p>如果您没有申请学生身份验证，请忽略此邮件。</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = "Link²Ur Student Verification"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    Student Verification
                </h2>
                <p>Hello,</p>
                <p>Thank you for using Link²Ur! Please click the link below to verify your student email:</p>
                {f'<p><strong>University:</strong> {university_name}</p>' if university_name else ''}
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{verification_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        Verify Student Email
                    </a>
                </div>
                
                <p>Or copy and paste the following link into your browser:</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{verification_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>Note:</strong> This link is valid for 15 minutes. Please verify as soon as possible.
                </p>
                <p>If you did not request student verification, please ignore this email.</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_student_expiry_reminder_email(language: str, days_remaining: int, expires_at: str, renewable_from: str, renewal_url: str = None) -> tuple[str, str]:
    """学生认证过期提醒邮件"""
    header = get_email_header()
    if language == 'zh':
        if days_remaining == 1:
            urgency_text = "明天"
            urgency_color = "#d32f2f"
        elif days_remaining <= 7:
            urgency_text = f"{days_remaining}天后"
            urgency_color = "#f57c00"
        else:
            urgency_text = f"{days_remaining}天后"
            urgency_color = "#1976d2"
        
        subject = f"【重要提醒】您的学生认证将在{urgency_text}过期"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: {urgency_color}; border-bottom: 2px solid {urgency_color}; padding-bottom: 10px;">
                    认证即将过期提醒
                </h2>
                <p>您好，</p>
                <p>您的学生认证将在 <strong style="color: {urgency_color};">{expires_at}</strong> 过期（还剩 <strong style="color: {urgency_color};">{days_remaining} 天</strong>）。</p>
                
                <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
                    <p style="margin: 0;"><strong>💡 续期提醒：</strong></p>
                    <p style="margin: 5px 0 0 0;">您可以在 <strong>{renewable_from}</strong> 开始续期认证。</p>
                </div>
                
                {f'''
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{renewal_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        立即续期认证
                    </a>
                </div>
                ''' if renewal_url else ''}
                
                <p style="color: #666; font-size: 14px;">
                    <strong>重要提示：</strong>
                </p>
                <ul style="color: #666; font-size: 14px;">
                    <li>认证过期后，您将无法享受学生专属功能</li>
                    <li>请在过期前及时续期，避免影响使用</li>
                    <li>续期需要重新验证您的学生邮箱</li>
                </ul>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        if days_remaining == 1:
            urgency_text = "tomorrow"
            urgency_color = "#d32f2f"
        elif days_remaining <= 7:
            urgency_text = f"in {days_remaining} days"
            urgency_color = "#f57c00"
        else:
            urgency_text = f"in {days_remaining} days"
            urgency_color = "#1976d2"
        
        subject = f"Important: Your Student Verification Expires {urgency_text}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: {urgency_color}; border-bottom: 2px solid {urgency_color}; padding-bottom: 10px;">
                    Verification Expiry Reminder
                </h2>
                <p>Hello,</p>
                <p>Your student verification will expire on <strong style="color: {urgency_color};">{expires_at}</strong> (<strong style="color: {urgency_color};">{days_remaining} days</strong> remaining).</p>
                
                <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
                    <p style="margin: 0;"><strong>💡 Renewal Notice:</strong></p>
                    <p style="margin: 5px 0 0 0;">You can renew your verification starting from <strong>{renewable_from}</strong>.</p>
                </div>
                
                {f'''
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{renewal_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        Renew Verification Now
                    </a>
                </div>
                ''' if renewal_url else ''}
                
                <p style="color: #666; font-size: 14px;">
                    <strong>Important Notes:</strong>
                </p>
                <ul style="color: #666; font-size: 14px;">
                    <li>After expiration, you will lose access to student-exclusive features</li>
                    <li>Please renew before expiration to avoid service interruption</li>
                    <li>Renewal requires re-verification of your student email</li>
                </ul>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_student_expiry_notification_email(language: str, expires_at: str, renewal_url: str = None) -> tuple[str, str]:
    """学生认证过期通知邮件（过期当天）"""
    header = get_email_header()
    if language == 'zh':
        subject = "【通知】您的学生认证已过期"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #d32f2f; border-bottom: 2px solid #d32f2f; padding-bottom: 10px;">
                    认证已过期
                </h2>
                <p>您好，</p>
                <p>您的学生认证已于 <strong style="color: #d32f2f;">{expires_at}</strong> 过期。</p>
                
                <div style="background: #ffebee; border-left: 4px solid #d32f2f; padding: 15px; margin: 20px 0;">
                    <p style="margin: 0;"><strong>⚠️ 重要提示：</strong></p>
                    <p style="margin: 5px 0 0 0;">认证过期后，您将无法享受学生专属功能。请尽快续期以恢复服务。</p>
                </div>
                
                {f'''
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{renewal_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        立即续期认证
                    </a>
                </div>
                ''' if renewal_url else ''}
                
                <p style="color: #666; font-size: 14px;">
                    <strong>续期说明：</strong>
                </p>
                <ul style="color: #666; font-size: 14px;">
                    <li>续期需要重新验证您的学生邮箱</li>
                    <li>验证通过后，认证将立即恢复</li>
                    <li>如有问题，请联系客服</li>
                </ul>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = "Notification: Your Student Verification Has Expired"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #d32f2f; border-bottom: 2px solid #d32f2f; padding-bottom: 10px;">
                    Verification Expired
                </h2>
                <p>Hello,</p>
                <p>Your student verification expired on <strong style="color: #d32f2f;">{expires_at}</strong>.</p>
                
                <div style="background: #ffebee; border-left: 4px solid #d32f2f; padding: 15px; margin: 20px 0;">
                    <p style="margin: 0;"><strong>⚠️ Important:</strong></p>
                    <p style="margin: 5px 0 0 0;">After expiration, you will lose access to student-exclusive features. Please renew as soon as possible to restore service.</p>
                </div>
                
                {f'''
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{renewal_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        Renew Verification Now
                    </a>
                </div>
                ''' if renewal_url else ''}
                
                <p style="color: #666; font-size: 14px;">
                    <strong>Renewal Instructions:</strong>
                </p>
                <ul style="color: #666; font-size: 14px;">
                    <li>Renewal requires re-verification of your student email</li>
                    <li>Verification will be restored immediately after verification</li>
                    <li>If you have any questions, please contact customer service</li>
                </ul>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body

