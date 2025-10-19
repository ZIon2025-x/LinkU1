"""
自动数据库迁移模块
用于在应用启动时自动运行数据库迁移
"""

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

def auto_migrate():
    """
    自动运行数据库迁移
    在Railway环境中，这个函数会被调用来确保数据库结构是最新的
    """
    try:
        # 检查是否在Railway环境中
        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        if not railway_env:
            logger.info("非Railway环境，跳过自动迁移")
            return
        
        logger.info("开始自动数据库迁移...")
        
        # 导入数据库相关模块
        from app.database import sync_engine
        from app.models import Base
        
        # 创建所有表（如果不存在）
        Base.metadata.create_all(bind=sync_engine)
        logger.info("数据库表创建/更新完成")
        
        # 这里可以添加更多的迁移逻辑
        # 例如：添加新列、创建索引等
        
        logger.info("自动数据库迁移完成")
        
    except Exception as e:
        logger.error(f"自动数据库迁移失败: {e}")
        # 不抛出异常，让应用继续启动
        pass