"""
邮件模板模块
提供所有邮件的中英文模板，根据用户语言偏好返回对应语言的内容
"""

from typing import Optional
from app.config import Config


def get_email_header() -> str:
    """生成邮件头部，包含logo"""
    logo_url = f"{Config.FRONTEND_URL}/static/favicon.png"
    return f"""
    <div style="text-align: center; padding: 20px 0; background-color: #ffffff; margin-bottom: 20px;">
        <img src="{logo_url}" alt="Link²Ur Logo" style="max-width: 200px; height: auto;" />
    </div>
    """


def get_user_language(user: Optional[object]) -> str:
    """获取用户语言偏好，默认为英文"""
    if not user:
        return 'en'
    
    language = getattr(user, 'language_preference', 'en')
    if language and isinstance(language, str):
        language = language.strip().lower()
        if language in ['zh', 'zh-cn', 'chinese']:
            return 'zh'
    return 'en'


# ==================== 验证码邮件模板 ====================

def get_login_verification_code_email(language: str, verification_code: str) -> tuple[str, str]:
    """登录验证码邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 登录验证码"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">登录验证码</h2>
            <p>您好，</p>
            <p>您正在尝试登录 Link²Ur 平台，请使用以下验证码完成登录：</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>重要提示：</strong><br>
                • 验证码有效期为 10 分钟<br>
                • 验证码只能使用一次<br>
                • 如果您没有尝试登录，请忽略此邮件<br>
                • 请勿将验证码泄露给他人
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                此邮件由 Link²Ur 系统自动发送，请勿回复。
            </p>
        </div>
        """
    else:
        subject = "Link²Ur Login Verification Code"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">Login Verification Code</h2>
            <p>Hello,</p>
            <p>You are attempting to log in to Link²Ur platform. Please use the following verification code to complete your login:</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>Important:</strong><br>
                • The verification code is valid for 10 minutes<br>
                • The verification code can only be used once<br>
                • If you did not attempt to log in, please ignore this email<br>
                • Do not share the verification code with others
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                This email is automatically sent by Link²Ur system. Please do not reply.
            </p>
        </div>
        """
    return subject, body


def get_email_update_verification_code_email(language: str, new_email: str, verification_code: str) -> tuple[str, str]:
    """邮箱修改验证码邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 邮箱修改验证码"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">邮箱修改验证码</h2>
            <p>您好，</p>
            <p>您正在尝试将 Link²Ur 账户的邮箱修改为：<strong>{new_email}</strong></p>
            <p>请使用以下验证码完成修改：</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>重要提示：</strong><br>
                • 验证码有效期为 10 分钟<br>
                • 验证码只能使用一次<br>
                • 如果您没有尝试修改邮箱，请忽略此邮件<br>
                • 请勿将验证码泄露给他人
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                此邮件由 Link²Ur 系统自动发送，请勿回复。
            </p>
        </div>
        """
    else:
        subject = "Link²Ur Email Update Verification Code"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">Email Update Verification Code</h2>
            <p>Hello,</p>
            <p>You are attempting to change your Link²Ur account email to: <strong>{new_email}</strong></p>
            <p>Please use the following verification code to complete the update:</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>Important:</strong><br>
                • The verification code is valid for 10 minutes<br>
                • The verification code can only be used once<br>
                • If you did not attempt to update your email, please ignore this email<br>
                • Do not share the verification code with others
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                This email is automatically sent by Link²Ur system. Please do not reply.
            </p>
        </div>
        """
    return subject, body


# ==================== 邮箱验证邮件模板 ====================

def get_email_verification_email(language: str, verification_url: str) -> tuple[str, str]:
    """邮箱验证邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 邮箱验证"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    欢迎注册 Link²Ur 平台！
                </h2>
                <p>您好，</p>
                <p>感谢您注册 Link²Ur 平台！请点击下面的链接验证您的邮箱地址：</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{verification_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        验证邮箱
                    </a>
                </div>
                
                <p>或者复制以下链接到浏览器中打开：</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{verification_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>注意：</strong>此链接24小时内有效，请及时验证。
                </p>
                <p>如果您没有注册 Link²Ur 账户，请忽略此邮件。</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = "Link²Ur Email Verification"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    Welcome to Link²Ur!
                </h2>
                <p>Hello,</p>
                <p>Thank you for registering with Link²Ur! Please click the link below to verify your email address:</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{verification_url}" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        Verify Email
                    </a>
                </div>
                
                <p>Or copy and paste the following link into your browser:</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{verification_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>Note:</strong> This link is valid for 24 hours. Please verify as soon as possible.
                </p>
                <p>If you did not register for a Link²Ur account, please ignore this email.</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


# ==================== 密码重置邮件模板 ====================

def get_password_reset_email(language: str, reset_url: str) -> tuple[str, str]:
    """密码重置邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 密码重置"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                    密码重置请求
                </h2>
                <p>您好，</p>
                <p>我们收到了您的密码重置请求。请点击下面的链接重置您的密码：</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{reset_url}" 
                       style="background: #f44336; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        重置密码
                    </a>
                </div>
                
                <p>或者复制以下链接到浏览器中打开：</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{reset_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>注意：</strong>此链接2小时内有效，请及时重置密码。
                </p>
                <p>如果您没有请求重置密码，请忽略此邮件，您的密码将不会被更改。</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = "Link²Ur Password Reset"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                    Password Reset Request
                </h2>
                <p>Hello,</p>
                <p>We received a request to reset your password. Please click the link below to reset your password:</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{reset_url}" 
                       style="background: #f44336; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        Reset Password
                    </a>
                </div>
                
                <p>Or copy and paste the following link into your browser:</p>
                <p style="word-break: break-all; color: #666; font-size: 12px;">{reset_url}</p>
                
                <p style="color: #666; font-size: 14px;">
                    <strong>Note:</strong> This link is valid for 2 hours. Please reset your password as soon as possible.
                </p>
                <p>If you did not request a password reset, please ignore this email. Your password will not be changed.</p>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


# ==================== 任务通知邮件模板 ====================

def get_task_application_email(language: str, task_title: str, task_description: str, 
                               reward: float, applicant_name: str, application_message: str = "",
                               negotiated_price: Optional[float] = None, currency: str = "GBP") -> tuple[str, str]:
    """任务申请通知邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = f"Link²Ur - 新任务申请：{task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    📝 新任务申请
                </h2>
                
                <p>您好！</p>
                
                <p>用户 <strong>{applicant_name}</strong> 申请了您发布的任务：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>任务描述：</strong>{task_description}</p>
                    <p><strong>任务奖励：</strong>£{reward:.2f}</p>
                </div>
                
                {f'<p><strong>申请留言：</strong>{application_message}</p>' if application_message else '<p><strong>申请留言：</strong>无</p>'}
                
                {f'<p><strong>议价金额：</strong>£{negotiated_price:.2f} {currency}</p>' if negotiated_price else '<p><strong>议价金额：</strong>无议价（使用任务原定金额）</p>'}
                
                <p>请登录 Link²Ur 平台查看申请详情并决定是否同意该用户接受任务。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - New Task Application: {task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    📝 New Task Application
                </h2>
                
                <p>Hello!</p>
                
                <p>User <strong>{applicant_name}</strong> has applied for your task:</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>Task Description:</strong> {task_description}</p>
                    <p><strong>Task Reward:</strong> £{reward:.2f}</p>
                </div>
                
                {f'<p><strong>Application Message:</strong> {application_message}</p>' if application_message else '<p><strong>Application Message:</strong> None</p>'}
                
                {f'<p><strong>Negotiated Price:</strong> £{negotiated_price:.2f} {currency}</p>' if negotiated_price else '<p><strong>Negotiated Price:</strong> No negotiation (using original task reward)</p>'}
                
                <p>Please log in to Link²Ur platform to view the application details and decide whether to approve this user for the task.</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        View Task Details
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_task_approval_email(language: str, task_title: str, task_description: str, reward: float) -> tuple[str, str]:
    """任务申请同意通知邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = f"Link²Ur - 任务申请已同意：{task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    ✅ 任务申请已同意
                </h2>
                
                <p>恭喜！</p>
                
                <p>您申请的任务已被发布者同意，现在可以开始执行任务了：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>任务描述：</strong>{task_description}</p>
                    <p><strong>任务奖励：</strong>£{reward:.2f}</p>
                </div>
                
                <p>请按照任务要求完成工作，完成后记得标记任务完成。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - Task Application Approved: {task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    ✅ Task Application Approved
                </h2>
                
                <p>Congratulations!</p>
                
                <p>Your task application has been approved by the poster. You can now start working on the task:</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>Task Description:</strong> {task_description}</p>
                    <p><strong>Task Reward:</strong> £{reward:.2f}</p>
                </div>
                
                <p>Please complete the work according to the task requirements. Remember to mark the task as completed when finished.</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        View Task Details
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_task_completion_email(language: str, task_title: str, task_description: str, 
                             reward: float, taker_name: str) -> tuple[str, str]:
    """任务完成通知邮件（给发布者）"""
    header = get_email_header()
    if language == 'zh':
        subject = f"Link²Ur - 任务已完成：{task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #ff9800; border-bottom: 2px solid #ff9800; padding-bottom: 10px;">
                    🎉 任务已完成
                </h2>
                
                <p>您好！</p>
                
                <p>用户 <strong>{taker_name}</strong> 已标记任务完成：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>任务描述：</strong>{task_description}</p>
                    <p><strong>任务奖励：</strong>£{reward:.2f}</p>
                </div>
                
                <p>请检查任务完成情况，如果满意请确认完成以释放奖励。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #ff9800; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看任务详情
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - Task Completed: {task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #ff9800; border-bottom: 2px solid #ff9800; padding-bottom: 10px;">
                    🎉 Task Completed
                </h2>
                
                <p>Hello!</p>
                
                <p>User <strong>{taker_name}</strong> has marked the task as completed:</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>Task Description:</strong> {task_description}</p>
                    <p><strong>Task Reward:</strong> £{reward:.2f}</p>
                </div>
                
                <p>Please review the task completion. If satisfied, please confirm completion to release the reward.</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #ff9800; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        View Task Details
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_task_confirmation_email(language: str, task_title: str, task_description: str, reward: float) -> tuple[str, str]:
    """任务确认完成通知邮件（给接收者）"""
    header = get_email_header()
    if language == 'zh':
        subject = f"Link²Ur - 任务已确认完成：{task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    🎊 任务已确认完成
                </h2>
                
                <p>恭喜！</p>
                
                <p>您完成的任务已被发布者确认，奖励已发放到您的账户：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>任务描述：</strong>{task_description}</p>
                    <p><strong>获得奖励：</strong>£{reward:.2f}</p>
                </div>
                
                <p>感谢您使用 Link²Ur 平台！继续寻找更多任务机会吧。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看更多任务
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - Task Confirmed: {task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
                    🎊 Task Confirmed
                </h2>
                
                <p>Congratulations!</p>
                
                <p>The task you completed has been confirmed by the poster. The reward has been credited to your account:</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>Task Description:</strong> {task_description}</p>
                    <p><strong>Reward Earned:</strong> £{reward:.2f}</p>
                </div>
                
                <p>Thank you for using Link²Ur platform! Continue to find more task opportunities.</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        View More Tasks
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


def get_task_rejection_email(language: str, task_title: str, task_description: str, reward: float) -> tuple[str, str]:
    """任务申请拒绝通知邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = f"Link²Ur - 任务申请被拒绝：{task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                    ❌ 任务申请被拒绝
                </h2>
                
                <p>很抱歉，</p>
                
                <p>您申请的任务被发布者拒绝了：</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>任务描述：</strong>{task_description}</p>
                    <p><strong>任务奖励：</strong>£{reward:.2f}</p>
                </div>
                
                <p>不要灰心！还有很多其他任务机会等着您。</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        查看更多任务
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - Task Application Rejected: {task_title}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                    ❌ Task Application Rejected
                </h2>
                
                <p>We're sorry,</p>
                
                <p>Your task application has been rejected by the poster:</p>
                
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0; color: #333;">{task_title}</h3>
                    <p><strong>Task Description:</strong> {task_description}</p>
                    <p><strong>Task Reward:</strong> £{reward:.2f}</p>
                </div>
                
                <p>Don't be discouraged! There are many other task opportunities waiting for you.</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/tasks" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                        View More Tasks
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


# ==================== 任务达人服务申请邮件模板 ====================

def get_service_application_email(
    language: str,
    service_name: str,
    service_description: str,
    base_price: float,
    applicant_name: str,
    applicant_email: str,
    application_message: str = "",
    negotiated_price: Optional[float] = None,
    currency: str = "GBP",
    deadline: Optional[str] = None,
    is_flexible: bool = False,
    application_time: str = "",
    service_id: int = 0
) -> tuple[str, str]:
    """任务达人服务申请通知邮件"""
    header = get_email_header()
    
    # 格式化价格显示
    currency_symbol = "£" if currency == "GBP" else currency
    base_price_str = f"{currency_symbol}{base_price:.2f}"
    negotiated_price_str = f"{currency_symbol}{negotiated_price:.2f}" if negotiated_price else None
    
    # 格式化截止日期
    deadline_str = deadline if deadline else None
    
    if language == 'zh':
        subject = f"Link²Ur - 新服务申请：{service_name}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    🎯 新服务申请
                </h2>
                
                <p>您好！</p>
                
                <p>用户 <strong>{applicant_name}</strong> 申请了您的服务：</p>
                
                <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #1976d2;">
                    <h3 style="margin-top: 0; color: #333; font-size: 20px;">{service_name}</h3>
                    <p style="color: #666; margin: 10px 0;"><strong>服务描述：</strong>{service_description}</p>
                    <p style="color: #666; margin: 10px 0;"><strong>基础价格：</strong>{base_price_str} {currency}</p>
                </div>
                
                <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
                    <h4 style="margin-top: 0; color: #856404;">📋 申请详情</h4>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="padding: 8px 0; color: #666; width: 120px;"><strong>申请用户：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{applicant_name}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>用户邮箱：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{applicant_email}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>申请时间：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{application_time}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>申请留言：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{application_message if application_message else '无'}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>议价金额：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{negotiated_price_str if negotiated_price_str else f'{base_price_str} {currency}（使用基础价格）'}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>货币类型：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{currency}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>时间要求：</strong></td>
                            <td style="padding: 8px 0; color: #333;">{'灵活时间（无固定截止日期）' if is_flexible else (f'截止日期：{deadline_str}' if deadline_str else '未指定')}</td>
                        </tr>
                    </table>
                </div>
                
                <div style="background: #e7f3ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <p style="margin: 0; color: #1976d2; font-weight: 600;">💡 下一步操作</p>
                    <p style="margin: 10px 0 0 0; color: #666;">请登录 Link²Ur 平台查看申请详情，您可以：</p>
                    <ul style="margin: 10px 0; padding-left: 20px; color: #666;">
                        <li>同意申请并创建任务</li>
                        <li>拒绝申请</li>
                        <li>提出议价（如果申请用户提出了议价）</li>
                    </ul>
                </div>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/expert-dashboard" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">
                        查看服务申请
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666; text-align: center;">
                    此邮件由 Link²Ur 平台自动发送，请勿回复。<br>
                    如有疑问，请联系客服：support@link2ur.com
                </p>
            </div>
        </body>
        </html>
        """
    else:
        subject = f"Link²Ur - New Service Application: {service_name}"
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">
                    🎯 New Service Application
                </h2>
                
                <p>Hello!</p>
                
                <p>User <strong>{applicant_name}</strong> has applied for your service:</p>
                
                <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #1976d2;">
                    <h3 style="margin-top: 0; color: #333; font-size: 20px;">{service_name}</h3>
                    <p style="color: #666; margin: 10px 0;"><strong>Service Description:</strong> {service_description}</p>
                    <p style="color: #666; margin: 10px 0;"><strong>Base Price:</strong> {base_price_str} {currency}</p>
                </div>
                
                <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
                    <h4 style="margin-top: 0; color: #856404;">📋 Application Details</h4>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="padding: 8px 0; color: #666; width: 140px;"><strong>Applicant:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{applicant_name}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Email:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{applicant_email}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Application Time:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{application_time}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Message:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{application_message if application_message else 'None'}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Negotiated Price:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{negotiated_price_str if negotiated_price_str else f'{base_price_str} {currency} (using base price)'}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Currency:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{currency}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; color: #666;"><strong>Time Requirement:</strong></td>
                            <td style="padding: 8px 0; color: #333;">{'Flexible time (no fixed deadline)' if is_flexible else (f'Deadline: {deadline_str}' if deadline_str else 'Not specified')}</td>
                        </tr>
                    </table>
                </div>
                
                <div style="background: #e7f3ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <p style="margin: 0; color: #1976d2; font-weight: 600;">💡 Next Steps</p>
                    <p style="margin: 10px 0 0 0; color: #666;">Please log in to Link²Ur platform to view the application details. You can:</p>
                    <ul style="margin: 10px 0; padding-left: 20px; color: #666;">
                        <li>Approve the application and create a task</li>
                        <li>Reject the application</li>
                        <li>Make a counter offer (if the applicant proposed a negotiated price)</li>
                    </ul>
                </div>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{Config.FRONTEND_URL}/expert-dashboard" 
                       style="background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: 600;">
                        View Service Applications
                    </a>
                </div>
                
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #666; text-align: center;">
                    This email is automatically sent by Link²Ur platform. Please do not reply.<br>
                    If you have any questions, please contact support: support@link2ur.com
                </p>
            </div>
        </body>
        </html>
        """
    return subject, body


# ==================== 管理员验证码邮件模板 ====================

def get_admin_verification_code_email(language: str, verification_code: str, admin_name: str, expire_minutes: int) -> tuple[str, str]:
    """管理员验证码邮件"""
    header = get_email_header()
    if language == 'zh':
        subject = "Link²Ur 管理员登录验证码"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">管理员登录验证码</h2>
            <p>尊敬的 {admin_name}，</p>
            <p>您正在尝试登录 Link²Ur 管理员系统，请使用以下验证码完成登录：</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>重要提示：</strong><br>
                • 验证码有效期为 {expire_minutes} 分钟<br>
                • 验证码只能使用一次<br>
                • 如果您没有尝试登录，请忽略此邮件<br>
                • 请勿将验证码泄露给他人
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                此邮件由 Link²Ur 系统自动发送，请勿回复。
            </p>
        </div>
        """
    else:
        subject = "Link²Ur Admin Login Verification Code"
        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            {header}
            <h2 style="color: #333; text-align: center;">Admin Login Verification Code</h2>
            <p>Dear {admin_name},</p>
            <p>You are attempting to log in to Link²Ur admin system. Please use the following verification code to complete your login:</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">{verification_code}</h1>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                <strong>Important:</strong><br>
                • The verification code is valid for {expire_minutes} minutes<br>
                • The verification code can only be used once<br>
                • If you did not attempt to log in, please ignore this email<br>
                • Do not share the verification code with others
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
                This email is automatically sent by Link²Ur system. Please do not reply.
            </p>
        </div>
        """
    return subject, body

