"""
风控系统
"""
import logging
from datetime import datetime, timedelta, timezone as tz
from typing import Optional, Dict, Any, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_

from app import models
from app.device_fingerprint import generate_device_fingerprint, get_ip_address
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_risk(
    db: Session,
    user_id: Optional[str],
    action_type: str,
    device_fingerprint: Optional[str] = None,
    ip_address: Optional[str] = None,
    meta_data: Optional[Dict[str, Any]] = None
) -> Tuple[bool, Optional[str], int]:
    """
    检查风险
    
    返回: (是否允许, 风险原因, 风险评分)
    """
    from app.crud import get_system_setting
    
    # 检查是否启用风控
    risk_control_enabled = get_system_setting(db, "risk_control_enabled")
    if risk_control_enabled and risk_control_enabled.setting_value.lower() != "true":
        return True, None, 0
    
    risk_score = 0
    risk_reasons = []
    
    # 检查设备指纹
    if device_fingerprint:
        device = db.query(models.DeviceFingerprint).filter(
            models.DeviceFingerprint.fingerprint == device_fingerprint
        ).first()
        
        if device:
            # 如果设备被标记为高风险或被封禁
            if device.is_blocked:
                return False, "设备已被封禁", 100
            
            # 检查设备关联的用户数量（多账号检测）
            user_count = db.query(func.count(func.distinct(models.DeviceFingerprint.user_id))).filter(
                models.DeviceFingerprint.fingerprint == device_fingerprint,
                models.DeviceFingerprint.user_id.isnot(None)
            ).scalar() or 0
            
            if user_count > 3:
                risk_score += 30
                risk_reasons.append(f"设备关联了{user_count}个账号")
            
            # 使用设备风险评分
            risk_score = max(risk_score, device.risk_score)
            
            # 更新最后访问时间
            device.last_seen = get_utc_time()
        else:
            # 新设备，创建记录
            device = models.DeviceFingerprint(
                fingerprint=device_fingerprint,
                user_id=user_id,
                ip_address=ip_address,
                device_info=meta_data.get("device_info") if meta_data else None,
                risk_score=0
            )
            db.add(device)
    
    # 检查IP地址
    if ip_address:
        # 检查同一IP在短时间内的操作次数
        if action_type == "checkin":
            max_per_day = int(get_system_setting(db, "max_checkin_per_device_per_day").setting_value) if get_system_setting(db, "max_checkin_per_device_per_day") else 1
            
            today_start = get_utc_time().replace(hour=0, minute=0, second=0, microsecond=0)
            checkin_count = db.query(func.count(models.CheckIn.id)).filter(
                and_(
                    models.CheckIn.ip_address == ip_address,
                    models.CheckIn.created_at >= today_start
                )
            ).scalar() or 0
            
            if checkin_count >= max_per_day:
                risk_score += 50
                risk_reasons.append(f"IP {ip_address} 今日签到次数过多")
        
        elif action_type == "coupon_claim":
            max_per_hour = int(get_system_setting(db, "max_coupon_claim_per_ip_per_hour").setting_value) if get_system_setting(db, "max_coupon_claim_per_ip_per_hour") else 10
            
            hour_ago = get_utc_time() - timedelta(hours=1)
            claim_count = db.query(func.count(models.UserCoupon.id)).filter(
                and_(
                    models.UserCoupon.ip_address == ip_address,
                    models.UserCoupon.created_at >= hour_ago
                )
            ).scalar() or 0
            
            if claim_count >= max_per_hour:
                risk_score += 40
                risk_reasons.append(f"IP {ip_address} 每小时领取优惠券次数过多")
    
    # 检查用户行为
    if user_id:
        # 检查用户短时间内频繁操作
        hour_ago = get_utc_time() - timedelta(hours=1)
        
        if action_type == "checkin":
            recent_checkins = db.query(func.count(models.CheckIn.id)).filter(
                and_(
                    models.CheckIn.user_id == user_id,
                    models.CheckIn.created_at >= hour_ago
                )
            ).scalar() or 0
            
            if recent_checkins > 1:
                risk_score += 20
                risk_reasons.append("用户短时间内多次签到")
        
        elif action_type == "points_earn":
            recent_earns = db.query(func.count(models.PointsTransaction.id)).filter(
                and_(
                    models.PointsTransaction.user_id == user_id,
                    models.PointsTransaction.type == "earn",
                    models.PointsTransaction.created_at >= hour_ago
                )
            ).scalar() or 0
            
            if recent_earns > 10:
                risk_score += 30
                risk_reasons.append("用户短时间内频繁获得积分")
    
    # 获取风险阈值
    high_threshold = int(get_system_setting(db, "risk_score_threshold_high").setting_value) if get_system_setting(db, "risk_score_threshold_high") else 70
    critical_threshold = int(get_system_setting(db, "risk_score_threshold_critical").setting_value) if get_system_setting(db, "risk_score_threshold_critical") else 90
    
    # 确定风险等级
    risk_level = "low"
    if risk_score >= critical_threshold:
        risk_level = "critical"
    elif risk_score >= high_threshold:
        risk_level = "high"
    elif risk_score >= 40:
        risk_level = "medium"
    
    # 记录风控日志
    risk_log = models.RiskControlLog(
        user_id=user_id,
        device_fingerprint=device_fingerprint,
        action_type=action_type,
        risk_level=risk_level,
        risk_reason="; ".join(risk_reasons) if risk_reasons else None,
        action_blocked=risk_score >= high_threshold,
        meta_data=meta_data
    )
    db.add(risk_log)
    
    # 如果风险评分高，更新设备风险评分
    if device_fingerprint and risk_score > 0:
        device = db.query(models.DeviceFingerprint).filter(
            models.DeviceFingerprint.fingerprint == device_fingerprint
        ).first()
        if device:
            # 使用加权平均更新风险评分
            device.risk_score = min(100, int((device.risk_score * 0.7 + risk_score * 0.3)))
            if risk_score >= critical_threshold:
                device.is_blocked = True
    
    # 判断是否允许操作
    is_allowed = risk_score < high_threshold
    risk_reason = "; ".join(risk_reasons) if risk_reasons else None
    
    return is_allowed, risk_reason, risk_score

