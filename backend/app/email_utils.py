import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv
from fastapi import BackgroundTasks
from itsdangerous import URLSafeTimedSerializer

load_dotenv()

# 使用统一配置
from app.config import Config

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


def send_email(to_email, subject, body):
    print(f"send_email called: to={to_email}, subject={subject}")
    
    # 检查SMTP配置是否完整
    if not SMTP_USER or not SMTP_PASS:
        print("SMTP配置不完整，跳过邮件发送")
        print(f"验证链接: {Config.BASE_URL}/api/users/verify-email/[token]")
        return
    
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
        
        print("Email sent successfully")
    except Exception as e:
        print(f"Email send failed: {e}")
        print("在开发环境中，这是正常的。请检查SMTP配置或设置SKIP_EMAIL_VERIFICATION=true")
        # 在开发环境中不抛出异常，避免影响注册流程
        # raise e


def send_confirmation_email(
    background_tasks: BackgroundTasks, to_email: str, token: str
):
    confirm_url = f"http://localhost:8000/api/users/confirm/{token}"
    subject = "LinkU Email Confirmation"
    body = (
        "<p>Welcome to LinkU! Please confirm your email by clicking the link below:</p>"
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


def send_reset_email(background_tasks: BackgroundTasks, to_email: str, token: str):
    reset_url = f"http://localhost:3000/reset-password/{token}"  # 改为前端页面地址
    subject = "LinkU Password Reset"
    body = "<p>To reset your password, click the link below:</p>"
    body += f'<p><a href="{reset_url}">{reset_url}</a></p>'
    background_tasks.add_task(send_email, to_email, subject, body)


def send_task_update_email(
    background_tasks: BackgroundTasks, to_email: str, subject: str, body: str
):
    background_tasks.add_task(send_email, to_email, subject, body)
