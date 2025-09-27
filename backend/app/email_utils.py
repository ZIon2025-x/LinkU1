import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv
from fastapi import BackgroundTasks
from itsdangerous import URLSafeTimedSerializer

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY", "linku_email_secret")
SALT = "email-confirm"
EMAIL_FROM = os.getenv("EMAIL_FROM", "noreply@linku.com")
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.163.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")

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
    try:
        msg = MIMEText(body, "html")
        msg["Subject"] = subject
        msg["From"] = EMAIL_FROM
        msg["To"] = to_email
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(EMAIL_FROM, [to_email], msg.as_string())
        print("Email sent successfully")
    except Exception as e:
        print(f"Email send failed: {e}")


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
