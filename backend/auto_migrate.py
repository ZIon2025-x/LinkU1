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
        
        # 移除 task_cancel_requests 表的 admin_id 外键约束（以支持客服ID）
        try:
            from sqlalchemy import text
            # 使用 autocommit 模式执行 DDL 语句
            with sync_engine.begin() as conn:
                # 检查并删除外键约束
                result = conn.execute(text("""
                    SELECT constraint_name 
                    FROM information_schema.table_constraints 
                    WHERE constraint_name = 'task_cancel_requests_admin_id_fkey'
                    AND table_name = 'task_cancel_requests'
                """))
                if result.fetchone():
                    conn.execute(text("""
                        ALTER TABLE task_cancel_requests 
                        DROP CONSTRAINT IF EXISTS task_cancel_requests_admin_id_fkey
                    """))
                    logger.info("已移除 task_cancel_requests.admin_id 外键约束")
        except Exception as e:
            logger.warning(f"移除外键约束时出错（可继续运行）: {e}")
        
        # 这里可以添加更多的迁移逻辑
        # 例如：添加新列、创建索引等
        
        logger.info("自动数据库迁移完成")
        
    except Exception as e:
        logger.error(f"自动数据库迁移失败: {e}")
        # 不抛出异常，让应用继续启动
        pass