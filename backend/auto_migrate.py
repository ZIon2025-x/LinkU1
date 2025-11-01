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
        # 始终执行迁移（不再检查环境变量）
        logger.info("开始自动数据库迁移...")
        
        # 导入数据库相关模块
        from app.database import sync_engine
        from app.models import Base
        
        # 创建所有表（如果不存在）
        Base.metadata.create_all(bind=sync_engine)
        logger.info("数据库表创建/更新完成")
        
        # 迁移 task_cancel_requests 表：将 admin_id 指向 admin_users，添加 service_id 字段
        try:
            from sqlalchemy import text
            with sync_engine.begin() as conn:
                # 1. 先移除所有旧的 admin_id 外键约束（可能指向 users 或 admin_users）
                constraints_result = conn.execute(text("""
                    SELECT constraint_name 
                    FROM information_schema.table_constraints 
                    WHERE constraint_name LIKE 'task_cancel_requests_admin_id%'
                    AND table_name = 'task_cancel_requests'
                    AND constraint_type = 'FOREIGN KEY'
                """))
                constraints = constraints_result.fetchall()
                for constraint in constraints:
                    constraint_name = constraint[0]
                    try:
                        conn.execute(text(f"""
                            ALTER TABLE task_cancel_requests 
                            DROP CONSTRAINT IF EXISTS {constraint_name}
                        """))
                        logger.info(f"已移除旧的约束: {constraint_name}")
                    except Exception as e:
                        logger.warning(f"移除约束 {constraint_name} 时出错: {e}")
                
                # 2. 检查并添加 service_id 字段
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'task_cancel_requests'
                    AND column_name = 'service_id'
                """))
                if not result.fetchone():
                    try:
                        conn.execute(text("""
                            ALTER TABLE task_cancel_requests 
                            ADD COLUMN service_id VARCHAR(6)
                        """))
                        # 添加外键约束
                        conn.execute(text("""
                            ALTER TABLE task_cancel_requests 
                            ADD CONSTRAINT task_cancel_requests_service_id_fkey 
                            FOREIGN KEY (service_id) REFERENCES customer_service(id)
                        """))
                        logger.info("已添加 task_cancel_requests.service_id 字段")
                    except Exception as e:
                        logger.warning(f"添加 service_id 字段时出错: {e}")
                
                # 3. 修改 admin_id 字段类型和外键约束（指向 admin_users）
                result = conn.execute(text("""
                    SELECT data_type, character_maximum_length
                    FROM information_schema.columns 
                    WHERE table_name = 'task_cancel_requests'
                    AND column_name = 'admin_id'
                """))
                col_info = result.fetchone()
                if col_info:
                    current_type = col_info[0]
                    current_length = col_info[1]
                    # 如果类型不是 VARCHAR(5)，需要修改
                    if current_type != 'character varying' or (current_length and current_length != 5):
                        try:
                            conn.execute(text("""
                                ALTER TABLE task_cancel_requests 
                                ALTER COLUMN admin_id TYPE VARCHAR(5) USING admin_id::VARCHAR(5)
                            """))
                            logger.info("已修改 task_cancel_requests.admin_id 字段类型为 VARCHAR(5)")
                        except Exception as e:
                            logger.warning(f"修改 admin_id 字段类型时出错: {e}")
                    
                    # 添加新的外键约束（指向 admin_users），如果不存在
                    try:
                        conn.execute(text("""
                            ALTER TABLE task_cancel_requests 
                            ADD CONSTRAINT task_cancel_requests_admin_id_fkey 
                            FOREIGN KEY (admin_id) REFERENCES admin_users(id)
                        """))
                        logger.info("已添加 task_cancel_requests.admin_id 外键约束（指向 admin_users）")
                    except Exception as e:
                        # 如果约束已存在，忽略错误
                        if "already exists" not in str(e).lower():
                            logger.warning(f"添加 admin_id 外键约束时出错: {e}")
                else:
                    # 如果字段不存在，创建它
                    try:
                        conn.execute(text("""
                            ALTER TABLE task_cancel_requests 
                            ADD COLUMN admin_id VARCHAR(5)
                        """))
                        conn.execute(text("""
                            ALTER TABLE task_cancel_requests 
                            ADD CONSTRAINT task_cancel_requests_admin_id_fkey 
                            FOREIGN KEY (admin_id) REFERENCES admin_users(id)
                        """))
                        logger.info("已创建 task_cancel_requests.admin_id 字段")
                    except Exception as e:
                        logger.warning(f"创建 admin_id 字段时出错: {e}")
                
        except Exception as e:
            logger.error(f"迁移 task_cancel_requests 表时出错: {e}")
            import traceback
            logger.error(traceback.format_exc())
        
        # 迁移 admin_requests 表：将 admin_id 指向 admin_users
        try:
            from sqlalchemy import text
            with sync_engine.begin() as conn:
                # 移除旧的 admin_id 外键约束（如果存在）
                result = conn.execute(text("""
                    SELECT constraint_name 
                    FROM information_schema.table_constraints 
                    WHERE constraint_name = 'admin_requests_admin_id_fkey'
                    AND table_name = 'admin_requests'
                """))
                if result.fetchone():
                    conn.execute(text("""
                        ALTER TABLE admin_requests 
                        DROP CONSTRAINT IF EXISTS admin_requests_admin_id_fkey
                    """))
                    logger.info("已移除旧的 admin_requests.admin_id 外键约束")
                
                # 修改 admin_id 字段类型并添加新的外键约束
                result = conn.execute(text("""
                    SELECT data_type, character_maximum_length
                    FROM information_schema.columns 
                    WHERE table_name = 'admin_requests'
                    AND column_name = 'admin_id'
                """))
                col_info = result.fetchone()
                if col_info:
                    current_type = col_info[0]
                    current_length = col_info[1]
                    if current_type != 'character varying' or current_length != 5:
                        conn.execute(text("""
                            ALTER TABLE admin_requests 
                            ALTER COLUMN admin_id TYPE VARCHAR(5)
                        """))
                        logger.info("已修改 admin_requests.admin_id 字段类型为 VARCHAR(5)")
                    
                    # 添加新的外键约束（指向 admin_users）
                    conn.execute(text("""
                        ALTER TABLE admin_requests 
                        ADD CONSTRAINT admin_requests_admin_id_fkey 
                        FOREIGN KEY (admin_id) REFERENCES admin_users(id)
                    """))
                    logger.info("已添加 admin_requests.admin_id 外键约束（指向 admin_users）")
        except Exception as e:
            logger.warning(f"迁移 admin_requests 表时出错（可继续运行）: {e}")
        
        # 这里可以添加更多的迁移逻辑
        # 例如：添加新列、创建索引等
        
        logger.info("自动数据库迁移完成")
        
    except Exception as e:
        logger.error(f"自动数据库迁移失败: {e}")
        # 不抛出异常，让应用继续启动
        pass