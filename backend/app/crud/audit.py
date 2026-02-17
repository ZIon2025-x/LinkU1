"""审计日志（AuditLog）相关 CRUD，独立模块便于维护与测试。"""
from sqlalchemy.orm import Session

from app.models import AuditLog


def create_audit_log(
    db: Session,
    action_type: str,
    entity_type: str,
    entity_id: str,
    admin_id: str = None,
    user_id: str = None,
    old_value: dict = None,
    new_value: dict = None,
    reason: str = None,
    ip_address: str = None,
    device_fingerprint: str = None,
):
    """创建审计日志记录。old_value / new_value 为 dict，JSONB 会自动处理。"""
    audit_log = AuditLog(
        action_type=action_type,
        entity_type=entity_type,
        entity_id=str(entity_id),
        admin_id=admin_id,
        user_id=user_id,
        old_value=old_value,
        new_value=new_value,
        reason=reason,
        ip_address=ip_address,
        device_fingerprint=device_fingerprint,
    )
    db.add(audit_log)
    db.commit()
    db.refresh(audit_log)
    return audit_log
