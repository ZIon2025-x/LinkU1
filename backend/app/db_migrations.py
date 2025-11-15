"""
数据库自动迁移工具
在应用启动时自动执行迁移脚本
"""
import os
import logging
from pathlib import Path
from sqlalchemy import text
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)

# 迁移文件列表（按执行顺序）
MIGRATION_FILES = [
    "add_points_reward_to_tasks.sql",
]

def run_migration(engine: Engine, migration_file: str) -> bool:
    """
    执行单个迁移文件
    
    Args:
        engine: SQLAlchemy引擎
        migration_file: 迁移文件名
        
    Returns:
        bool: 是否执行成功
    """
    try:
        # 获取迁移文件路径
        migrations_dir = Path(__file__).parent.parent / "migrations"
        migration_path = migrations_dir / migration_file
        
        if not migration_path.exists():
            logger.warning(f"迁移文件不存在: {migration_path}")
            return False
        
        # 读取SQL文件
        with open(migration_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # 分割SQL语句（按分号分割，但保留注释）
        # 移除注释和空行，只执行实际的SQL语句
        statements = []
        current_statement = ""
        
        for line in sql_content.split('\n'):
            line = line.strip()
            # 跳过注释和空行
            if not line or line.startswith('--'):
                continue
            
            current_statement += line + '\n'
            
            # 如果行以分号结尾，说明是一个完整的语句
            if line.endswith(';'):
                statements.append(current_statement.strip())
                current_statement = ""
        
        # 执行所有SQL语句
        with engine.connect() as conn:
            for statement in statements:
                if statement:
                    try:
                        conn.execute(text(statement))
                        logger.info(f"✅ 执行SQL语句成功: {statement[:50]}...")
                    except Exception as e:
                        # 如果是"已存在"的错误，可以忽略
                        error_msg = str(e).lower()
                        if 'already exists' in error_msg or 'duplicate' in error_msg:
                            logger.info(f"ℹ️  跳过已存在的对象: {statement[:50]}...")
                        else:
                            logger.error(f"❌ 执行SQL语句失败: {e}")
                            logger.error(f"   语句: {statement[:100]}...")
                            raise
            
            # 提交事务
            conn.commit()
        
        logger.info(f"✅ 迁移文件执行成功: {migration_file}")
        return True
        
    except Exception as e:
        logger.error(f"❌ 执行迁移文件失败 {migration_file}: {e}", exc_info=True)
        return False


def run_all_migrations(engine: Engine) -> bool:
    """
    执行所有迁移文件
    
    Args:
        engine: SQLAlchemy引擎
        
    Returns:
        bool: 是否全部执行成功
    """
    logger.info("🔄 开始执行数据库迁移...")
    
    success_count = 0
    failed_count = 0
    
    for migration_file in MIGRATION_FILES:
        logger.info(f"📝 执行迁移: {migration_file}")
        if run_migration(engine, migration_file):
            success_count += 1
        else:
            failed_count += 1
    
    if failed_count == 0:
        logger.info(f"✅ 所有迁移执行成功！共 {success_count} 个迁移文件")
        return True
    else:
        logger.error(f"❌ 迁移执行完成，成功: {success_count}, 失败: {failed_count}")
        return False


def check_migration_needed(engine: Engine) -> bool:
    """
    检查是否需要执行迁移
    
    Args:
        engine: SQLAlchemy引擎
        
    Returns:
        bool: 是否需要迁移
    """
    try:
        with engine.connect() as conn:
            # 检查 tasks 表是否存在
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 
                    FROM information_schema.tables 
                    WHERE table_name = 'tasks'
                )
            """))
            tasks_table_exists = result.scalar()
            
            if not tasks_table_exists:
                logger.info("tasks 表不存在，将在创建表后执行迁移")
                return True
            
            # 检查 tasks 表是否有 points_reward 字段
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 
                    FROM information_schema.columns 
                    WHERE table_name = 'tasks' AND column_name = 'points_reward'
                )
            """))
            has_field = result.scalar()
            
            # 检查 system_settings 表是否存在
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 
                    FROM information_schema.tables 
                    WHERE table_name = 'system_settings'
                )
            """))
            settings_table_exists = result.scalar()
            
            if not settings_table_exists:
                logger.info("system_settings 表不存在，将在创建表后执行迁移")
                return True
            
            # 检查系统设置是否存在
            result = conn.execute(text("""
                SELECT COUNT(*) 
                FROM system_settings 
                WHERE setting_key IN ('points_task_complete_bonus', 'checkin_daily_base_points')
            """))
            settings_count = result.scalar()
            
            has_settings = settings_count >= 2
            
            # 如果字段和设置都存在，则不需要迁移
            needs_migration = not (has_field and has_settings)
            
            if not needs_migration:
                logger.info("✅ 数据库迁移检查：已是最新版本")
            else:
                logger.info(f"🔄 数据库迁移检查：需要迁移 (字段存在: {has_field}, 设置存在: {has_settings})")
            
            return needs_migration
            
    except Exception as e:
        logger.warning(f"检查迁移状态失败: {e}，将尝试执行迁移")
        return True
