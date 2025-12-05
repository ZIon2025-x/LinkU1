"""
学生认证管理接口
管理员可以撤销认证、延长认证等操作
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, validator

from app import models
from app.deps import get_sync_db
from app.separate_auth_deps import get_current_admin
from app.student_verification_utils import calculate_expires_at
from app.utils.time_utils import format_iso_utc, get_utc_time
from app.email_utils import send_email
from app.config import Config

logger = logging.getLogger(__name__)

router = APIRouter()


class RevokeRequest(BaseModel):
    """撤销认证请求"""
    reason_type: str  # 必填：user_request, violation, account_hacked, other
    reason_detail: str  # 必填：撤销原因详情
    
    @validator('reason_type')
    def validate_reason_type(cls, v):
        allowed_types = ['user_request', 'violation', 'account_hacked', 'other']
        if v not in allowed_types:
            raise ValueError(f'reason_type 必须是以下之一: {allowed_types}')
        return v
    
    @validator('reason_detail')
    def validate_reason_detail(cls, v, values):
        if not v or not v.strip():
            raise ValueError('reason_detail 不能为空')
        # 如果 reason_type 为 other，reason_detail 必须手输详细原因
        if values.get('reason_type') == 'other' and len(v.strip()) < 10:
            raise ValueError('reason_type 为 other 时，reason_detail 必须手输至少10个字符的详细原因')
        return v.strip()


class ExtendRequest(BaseModel):
    """延长认证请求"""
    new_expires_at: datetime  # 新的过期时间


def send_revocation_notification_email(
    email: str,
    revoked_at: datetime,
    reason_type: str,
    reason_detail: str
):
    """发送撤销通知邮件"""
    reason_type_map = {
        'user_request': '用户自行申请注销',
        'violation': '涉嫌违规使用',
        'account_hacked': '账号被盗',
        'other': '其他原因'
    }
    
    reason_type_cn = reason_type_map.get(reason_type, reason_type)
    
    subject = "您的学生身份已被注销"
    body = f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #f44336; border-bottom: 2px solid #f44336; padding-bottom: 10px;">
                学生身份认证已撤销
            </h2>
            <p>您好，</p>
            <p>您的学生身份认证已被管理员撤销。</p>
            
            <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <p><strong>撤销时间：</strong>{format_iso_utc(revoked_at)}</p>
                <p><strong>撤销原因类型：</strong>{reason_type_cn}</p>
                <p><strong>撤销原因详情：</strong>{reason_detail}</p>
            </div>
            
            <p><strong>重要说明：</strong></p>
            <ul>
                <li>您的学生邮箱已释放，可以被其他用户使用</li>
                <li>如需重新认证，请重新提交认证申请</li>
                <li>如有疑问，请联系客服</li>
            </ul>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="font-size: 12px; color: #666;">
                此邮件为系统自动发送，请勿回复。如需帮助，请联系 support@link2ur.com
            </p>
        </div>
    </body>
    </html>
    """
    
    try:
        send_email(email, subject, body)
        logger.info(f"撤销通知邮件已发送: {email}")
        return True
    except Exception as e:
        logger.error(f"发送撤销通知邮件失败: {e}")
        return False


@router.post("/student-verification/{verification_id}/revoke")
def revoke_verification(
    verification_id: int,
    request: RevokeRequest,
    background_tasks: BackgroundTasks,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    """
    手动撤销认证
    
    处理流程：
    1. 查询认证记录
    2. 验证撤销原因（reason_type 和 reason_detail 必填）
    3. 更新状态为 revoked
    4. 记录撤销时间和原因
    5. 撤销后立即释放邮箱
    6. 异步发送撤销通知邮件
    """
    # 查询认证记录
    verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.id == verification_id
    ).first()
    
    if not verification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": 404,
                "message": "认证记录不存在",
                "error": "VERIFICATION_NOT_FOUND"
            }
        )
    
    if verification.status == 'revoked':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "认证已被撤销",
                "error": "ALREADY_REVOKED"
            }
        )
    
    # 保存原状态
    previous_status = verification.status
    
    # 更新状态
    now = get_utc_time()
    verification.status = 'revoked'
    verification.revoked_at = now
    verification.revoked_reason = f"{request.reason_type}: {request.reason_detail}"
    verification.revoked_reason_type = request.reason_type
    
    # 记录历史
    history = models.VerificationHistory(
        verification_id=verification.id,
        user_id=verification.user_id,
        university_id=verification.university_id,
        email=verification.email,
        action='revoked',
        previous_status=previous_status,
        new_status='revoked'
    )
    db.add(history)
    
    db.commit()
    db.refresh(verification)
    
    # 异步发送撤销通知邮件
    background_tasks.add_task(
        send_revocation_notification_email,
        verification.email,
        now,
        request.reason_type,
        request.reason_detail
    )
    
    return {
        "code": 200,
        "message": "认证已撤销，邮箱已释放",
        "data": {
            "verification_id": verification_id,
            "email": verification.email,
            "status": "revoked",
            "revoked_at": format_iso_utc(verification.revoked_at),
            "revoked_reason_type": request.reason_type,
            "revoked_reason_detail": request.reason_detail,
            "email_released": True,
            "notification_sent": True
        }
    }


@router.post("/student-verification/{verification_id}/extend")
def extend_verification(
    verification_id: int,
    request: ExtendRequest,
    current_admin: models.AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_sync_db),
):
    """
    手动延长认证
    
    处理流程：
    1. 查询认证记录
    2. 验证新的过期时间
    3. 更新过期时间
    4. 记录历史
    """
    # 查询认证记录
    verification = db.query(models.StudentVerification).filter(
        models.StudentVerification.id == verification_id
    ).first()
    
    if not verification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": 404,
                "message": "认证记录不存在",
                "error": "VERIFICATION_NOT_FOUND"
            }
        )
    
    if verification.status != 'verified':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "只能延长已验证的认证",
                "error": "INVALID_STATUS"
            }
        )
    
    # 验证新的过期时间
    if request.new_expires_at.tzinfo is None:
        new_expires_at = request.new_expires_at.replace(tzinfo=timezone.utc)
    else:
        new_expires_at = request.new_expires_at
    
    if new_expires_at <= verification.expires_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": 400,
                "message": "新的过期时间必须晚于当前过期时间",
                "error": "INVALID_EXPIRES_AT"
            }
        )
    
    # 更新过期时间
    old_expires_at = verification.expires_at
    verification.expires_at = new_expires_at
    
    # 记录历史
    history = models.VerificationHistory(
        verification_id=verification.id,
        user_id=verification.user_id,
        university_id=verification.university_id,
        email=verification.email,
        action='extended',
        previous_status='verified',
        new_status='verified'
    )
    db.add(history)
    
    db.commit()
    db.refresh(verification)
    
    return {
        "code": 200,
        "message": "认证已延长",
        "data": {
            "verification_id": verification_id,
            "email": verification.email,
            "old_expires_at": format_iso_utc(old_expires_at),
            "new_expires_at": format_iso_utc(verification.expires_at)
        }
    }

