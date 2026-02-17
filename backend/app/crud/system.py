
"""系统设置相关 CRUD，独立模块便于维护与测试。"""
from sqlalchemy.orm import Session

from app import models, schemas
from app.utils.time_utils import get_utc_time


def get_system_setting(db: Session, setting_key: str):
    """获取系统设置"""
    return (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )


def get_all_system_settings(db: Session):
    """获取所有系统设置"""
    return db.query(models.SystemSettings).all()


def create_system_setting(db: Session, setting: schemas.SystemSettingsCreate):
    """创建系统设置"""
    db_setting = models.SystemSettings(
        setting_key=setting.setting_key,
        setting_value=setting.setting_value,
        setting_type=setting.setting_type,
        description=setting.description,
    )
    db.add(db_setting)
    db.commit()
    db.refresh(db_setting)
    return db_setting


def update_system_setting(
    db: Session, setting_key: str, setting_value: str, description: str = None
):
    """更新系统设置"""
    db_setting = (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )
    if db_setting:
        db_setting.setting_value = setting_value
        if description is not None:
            db_setting.description = description
        db_setting.updated_at = get_utc_time()
        db.commit()
        db.refresh(db_setting)
    return db_setting


def upsert_system_setting(
    db: Session,
    setting_key: str,
    setting_value: str,
    setting_type: str = "string",
    description: str = None,
):
    """创建或更新系统设置"""
    db_setting = (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )
    if db_setting:
        db_setting.setting_value = setting_value
        if description is not None:
            db_setting.description = description
        db_setting.updated_at = get_utc_time()
    else:
        db_setting = models.SystemSettings(
            setting_key=setting_key,
            setting_value=setting_value,
            setting_type=setting_type,
            description=description,
        )
        db.add(db_setting)

    db.commit()
    db.refresh(db_setting)
    return db_setting


def bulk_update_system_settings(
    db: Session, settings_data: schemas.SystemSettingsBulkUpdate
):
    """批量更新系统设置"""
    settings_map = {
        "vip_enabled": str(settings_data.vip_enabled),
        "super_vip_enabled": str(settings_data.super_vip_enabled),
        "vip_task_threshold": str(settings_data.vip_task_threshold),
        "super_vip_task_threshold": str(settings_data.super_vip_task_threshold),
        "vip_price_threshold": str(settings_data.vip_price_threshold),
        "super_vip_price_threshold": str(settings_data.super_vip_price_threshold),
        "vip_button_visible": str(settings_data.vip_button_visible),
        "vip_auto_upgrade_enabled": str(settings_data.vip_auto_upgrade_enabled),
        "vip_benefits_description": settings_data.vip_benefits_description,
        "super_vip_benefits_description": settings_data.super_vip_benefits_description,
        "vip_to_super_task_count_threshold": str(
            settings_data.vip_to_super_task_count_threshold
        ),
        "vip_to_super_rating_threshold": str(
            settings_data.vip_to_super_rating_threshold
        ),
        "vip_to_super_completion_rate_threshold": str(
            settings_data.vip_to_super_completion_rate_threshold
        ),
        "vip_to_super_enabled": str(settings_data.vip_to_super_enabled),
    }

    updated_settings = []
    for key, value in settings_map.items():
        setting = upsert_system_setting(
            db=db,
            setting_key=key,
            setting_value=value,
            setting_type=(
                "boolean"
                if key.endswith("_enabled") or key.endswith("_visible")
                else (
                    "number"
                    if key.endswith("_threshold") or key.endswith("_rate_threshold")
                    else "string"
                )
            ),
            description=f"系统设置: {key}",
        )
        updated_settings.append(setting)

    return updated_settings


def get_system_settings_dict(db: Session):
    """获取系统设置字典"""
    settings = get_all_system_settings(db)
    settings_dict = {}
    for setting in settings:
        if setting.setting_type == "boolean":
            settings_dict[setting.setting_key] = setting.setting_value.lower() == "true"
        elif setting.setting_type == "number":
            try:
                float_val = float(setting.setting_value)
                settings_dict[setting.setting_key] = (
                    int(float_val) if float_val.is_integer() else float_val
                )
            except ValueError:
                settings_dict[setting.setting_key] = 0
        else:
            settings_dict[setting.setting_key] = setting.setting_value
    return settings_dict
