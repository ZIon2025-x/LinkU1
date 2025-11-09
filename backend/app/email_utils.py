import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv
from fastapi import BackgroundTasks
from itsdangerous import URLSafeTimedSerializer

load_dotenv()

# 使用统一配置
from app.config import Config
import logging

logger = logging.getLogger(__name__)

# 尝试导入SendGrid
try:
    import sendgrid
    from sendgrid.helpers.mail import Mail, Email, To, Content
    SENDGRID_AVAILABLE = True
except ImportError:
    SENDGRID_AVAILABLE = False

# 尝试导入Resend
try:
    import resend
    RESEND_AVAILABLE = True
except ImportError:
    RESEND_AVAILABLE = False

SECRET_KEY = Config.SECRET_KEY
SALT = "email-confirm"
EMAIL_FROM = Config.EMAIL_FROM
SMTP_SERVER = Config.SMTP_SERVER
SMTP_PORT = Config.SMTP_PORT
SMTP_USER = Config.SMTP_USER
SMTP_PASS = Config.SMTP_PASS
SMTP_USE_TLS = Config.SMTP_USE_TLS
SMTP_USE_SSL = Config.SMTP_USE_SSL

serializer = URLSafeTimedSerializer(SECRET_KEY)


def generate_confirmation_token(email):
    return serializer.dumps(email, salt=SALT)


def confirm_token(token, expiration=3600 * 24):
    try:
        email = serializer.loads(token, salt=SALT, max_age=expiration)
    except Exception:
        return None
    return email


def send_email_sendgrid(to_email, subject, body):
    """使用SendGrid发送邮件"""
    if not SENDGRID_AVAILABLE:
        print("SendGrid库未安装，回退到SMTP")
        return send_email_smtp(to_email, subject, body)
    
    try:
        sg = sendgrid.SendGridAPIClient(api_key=Config.SENDGRID_API_KEY)
        
        from_email = Email(Config.EMAIL_FROM)
        to_email = To(to_email)
        subject = subject
        content = Content("text/html", body)
        
        mail = Mail(from_email, to_email, subject, content)
        
        response = sg.send(mail)
        print(f"SendGrid邮件发送成功: {response.status_code}")
        return True
        
    except Exception as e:
        print(f"SendGrid邮件发送失败: {e}")
        print("回退到SMTP发送")
        return send_email_smtp(to_email, subject, body)

def send_email_resend(to_email, subject, body):
    """使用Resend发送邮件"""
    if not RESEND_AVAILABLE:
        print("Resend库未安装，回退到SMTP")
        return send_email_smtp(to_email, subject, body)
    
    try:
        resend.api_key = Config.RESEND_API_KEY
        
        params = {
            "from": Config.EMAIL_FROM,
            "to": [to_email],
            "subject": subject,
            "html": body,
        }
        
        email = resend.Emails.send(params)
        print(f"Resend邮件发送成功: {email}")
        return True
        
    except Exception as e:
        print(f"Resend邮件发送失败: {e}")
        print("回退到SMTP发送")
        return send_email_smtp(to_email, subject, body)

def send_email_smtp(to_email, subject, body):
    """使用SMTP发送邮件"""
    print(f"send_email_smtp called: to={to_email}, subject={subject}")
    
    # 检查SMTP配置是否完整
    if not SMTP_USER or not SMTP_PASS:
        print("SMTP配置不完整，跳过邮件发送")
        print(f"验证链接: {Config.BASE_URL}/api/users/verify-email/[token]")
        return False
    
    try:
        msg = MIMEText(body, "html")
        msg["Subject"] = subject
        msg["From"] = EMAIL_FROM
        msg["To"] = to_email
        
        # 根据配置选择SMTP连接方式
        if SMTP_USE_SSL:
            # 使用SSL连接
            with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
                server.login(SMTP_USER, SMTP_PASS)
                server.sendmail(EMAIL_FROM, [to_email], msg.as_string())
        else:
            # 使用TLS连接
            with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
                if SMTP_USE_TLS:
                    server.starttls()
                server.login(SMTP_USER, SMTP_PASS)
                server.sendmail(EMAIL_FROM, [to_email], msg.as_string())
        
        print("SMTP邮件发送成功")
        return True
    except Exception as e:
        print(f"SMTP邮件发送失败: {e}")
        print("在开发环境中，这是正常的。请检查SMTP配置或设置SKIP_EMAIL_VERIFICATION=true")
        return False

def send_email(to_email, subject, body):
    """智能邮件发送 - 优先使用Resend，然后SendGrid，最后SMTP"""
    print(f"send_email called: to={to_email}, subject={subject}")
    
    # 检查是否使用Resend
    if Config.USE_RESEND and Config.RESEND_API_KEY:
        print("使用Resend发送邮件")
        return send_email_resend(to_email, subject, body)
    
    # 检查是否使用SendGrid
    if Config.USE_SENDGRID and Config.SENDGRID_API_KEY:
        print("使用SendGrid发送邮件")
        return send_email_sendgrid(to_email, subject, body)
    
    # 回退到SMTP
    print("使用SMTP发送邮件")
    return send_email_smtp(to_email, subject, body)


def send_confirmation_email(
    background_tasks: BackgroundTasks, to_email: str, token: str
):
    confirm_url = f"{Config.BASE_URL}/api/users/confirm/{token}"
    subject = "Link²Ur Email Confirmation"
    body = (
        "<p>Welcome to Link²Ur! Please confirm your email by clicking the link below:</p>"
    )
    body += f'<p><a href="{confirm_url}">{confirm_url}</a></p>'
    background_tasks.add_task(send_email, to_email, subject, body)


def generate_reset_token(email):
    return serializer.dumps(email, salt="reset-password")


def confirm_reset_token(token, expiration=3600 * 2):
    try:
        email = serializer.loads(token, salt="reset-password", max_age=expiration)
    except Exception:
        return None
    return email


def send_reset_email(background_tasks: BackgroundTasks, to_email: str, token: str, language: str = 'en'):
    """发送密码重置邮件，根据语言偏好"""
    from app.email_templates import get_password_reset_email
    
    reset_url = f"{Config.FRONTEND_URL}/reset-password/{token}"  # 使用配置的前端URL
    subject, body = get_password_reset_email(language, reset_url)
    background_tasks.add_task(send_email, to_email, subject, body)


def send_task_update_email(
    background_tasks: BackgroundTasks, to_email: str, subject: str, body: str
):
    background_tasks.add_task(send_email, to_email, subject, body)


def send_admin_verification_code_email(
    background_tasks: BackgroundTasks, to_email: str, verification_code: str, admin_name: str, language: str = 'en'
):
    """发送管理员验证码邮件，根据语言偏好"""
    from app.email_templates import get_admin_verification_code_email
    
    subject, body = get_admin_verification_code_email(
        language, verification_code, admin_name, Config.ADMIN_VERIFICATION_CODE_EXPIRE_MINUTES
    )
    
    background_tasks.add_task(send_email, to_email, subject, body)
    logger.info(f"管理员验证码邮件已发送到: {to_email}")