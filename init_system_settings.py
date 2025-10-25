#!/usr/bin/env python3
"""
初始化系统设置数据
"""

import sys
import os
sys.path.append('backend')

from backend.app.database import SessionLocal
from backend.app import crud

def init_system_settings():
    """初始化系统设置"""
    db = SessionLocal()
    try:
        print("开始初始化系统设置...")
        
        # 默认系统设置
        default_settings = {
            "vip_enabled": ("true", "boolean", "VIP功能开关"),
            "super_vip_enabled": ("true", "boolean", "超级VIP功能开关"),
            "vip_task_threshold": ("5", "number", "VIP任务数量阈值"),
            "super_vip_task_threshold": ("20", "number", "超级VIP任务数量阈值"),
            "vip_price_threshold": ("10.0", "number", "VIP任务价格阈值"),
            "super_vip_price_threshold": ("50.0", "number", "超级VIP任务价格阈值"),
            "vip_button_visible": ("true", "boolean", "VIP按钮显示开关"),
            "vip_auto_upgrade_enabled": ("false", "boolean", "VIP自动升级开关"),
            "vip_benefits_description": ("优先任务推荐、专属客服服务、任务发布数量翻倍", "string", "VIP权益描述"),
            "super_vip_benefits_description": ("所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识", "string", "超级VIP权益描述"),
            "vip_to_super_task_count_threshold": ("50", "number", "VIP晋升超级VIP任务数量阈值"),
            "vip_to_super_rating_threshold": ("4.5", "number", "VIP晋升超级VIP评分阈值"),
            "vip_to_super_completion_rate_threshold": ("0.8", "number", "VIP晋升超级VIP完成率阈值"),
            "vip_to_super_enabled": ("true", "boolean", "VIP晋升超级VIP开关"),
        }
        
        # 创建或更新每个设置
        for key, (value, setting_type, description) in default_settings.items():
            try:
                crud.upsert_system_setting(
                    db=db,
                    setting_key=key,
                    setting_value=value,
                    setting_type=setting_type,
                    description=description
                )
                print(f"✓ 设置 {key} = {value}")
            except Exception as e:
                print(f"✗ 设置 {key} 失败: {e}")
        
        print("\n系统设置初始化完成！")
        
        # 验证设置
        print("\n验证设置...")
        settings = crud.get_system_settings_dict(db)
        for key in default_settings.keys():
            if key in settings:
                print(f"✓ {key}: {settings[key]}")
            else:
                print(f"✗ {key}: 未找到")
                
    except Exception as e:
        print(f"初始化失败: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    init_system_settings()
