#!/usr/bin/env python3
"""
修复迁移脚本 007_add_multi_participant_tasks.sql
手动执行迁移，每个语句独立事务，避免事务中止影响
"""

import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent))

from app.database import sync_engine
from sqlalchemy import text
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

MIGRATION_FILE = Path(__file__).parent / "migrations" / "007_add_multi_participant_tasks.sql"


def execute_migration():
    """执行迁移脚本，每个语句独立事务"""
    logger.info("开始执行迁移修复脚本...")
    
    if not MIGRATION_FILE.exists():
        logger.error(f"迁移文件不存在: {MIGRATION_FILE}")
        return False
    
    # 读取 SQL 文件内容
    sql_content = MIGRATION_FILE.read_text(encoding='utf-8')
    
    # 解析 SQL 语句（正确处理 DO $$ ... END $$; 块）
    statements = []
    current_statement = []
    in_do_block = False
    
    for line in sql_content.split('\n'):
        stripped = line.strip()
        
        # 跳过空行和注释行
        if not stripped or stripped.startswith('--'):
            continue
        
        # 检测 DO $$ 块开始
        if 'DO $$' in stripped.upper() and not in_do_block:
            in_do_block = True
        
        current_statement.append(line)
        
        # 检测 DO $$ 块结束
        if in_do_block:
            # 检查是否包含 END $$;
            if 'END $$;' in stripped.upper():
                in_do_block = False
                # DO 块结束，保存整个块
                statement = '\n'.join(current_statement).strip()
                if statement:
                    statements.append(statement)
                current_statement = []
            # 在 DO 块内，不按分号分割
            continue
        
        # 不在 DO 块内，按分号分割
        if stripped.endswith(';'):
            statement = '\n'.join(current_statement).strip()
            if statement:
                statements.append(statement)
            current_statement = []
    
    # 处理最后一个语句（可能没有分号）
    if current_statement:
        statement = '\n'.join(current_statement).strip()
        if statement:
            statements.append(statement)
    
    logger.info(f"解析到 {len(statements)} 个 SQL 语句")
    
    # 执行每个语句（每个语句独立事务）
    success_count = 0
    skip_count = 0
    error_count = 0
    
    with sync_engine.connect() as conn:
        for i, statement in enumerate(statements, 1):
            if not statement:
                continue
            
            # 每个语句在独立事务中执行
            trans = conn.begin()
            try:
                conn.execute(text(statement))
                trans.commit()
                success_count += 1
                logger.info(f"✅ ({i}/{len(statements)}) 执行成功")
            except Exception as e:
                trans.rollback()
                error_msg = str(e).lower()
                
                # 检查是否是"已存在"错误
                if any(keyword in error_msg for keyword in [
                    "already exists", "duplicate", "does not exist",
                    "already has", "relation already exists",
                    "constraint.*already exists", "already exists"
                ]):
                    skip_count += 1
                    logger.debug(f"⏭️  ({i}/{len(statements)}) 已存在，跳过: {statement[:50]}...")
                elif "current transaction is aborted" in error_msg:
                    error_count += 1
                    logger.warning(f"⚠️  ({i}/{len(statements)}) 事务中止（已回滚）: {statement[:50]}...")
                else:
                    error_count += 1
                    logger.error(f"❌ ({i}/{len(statements)}) 执行失败: {e}")
                    logger.debug(f"问题语句: {statement[:100]}...")
    
    logger.info(f"迁移完成: {success_count} 个成功, {skip_count} 个跳过, {error_count} 个失败")
    
    # 标记迁移为已执行（即使有部分失败）
    if success_count > 0 or skip_count > 0:
        try:
            with sync_engine.connect() as conn:
                conn.execute(text("""
                    INSERT INTO schema_migrations (migration_name, execution_time_ms)
                    VALUES (:name, 0)
                    ON CONFLICT (migration_name) DO NOTHING
                """), {"name": MIGRATION_FILE.name})
                conn.commit()
                logger.info("✅ 迁移记录已更新")
        except Exception as e:
            logger.warning(f"更新迁移记录失败: {e}")
    
    return error_count == 0


if __name__ == "__main__":
    success = execute_migration()
    sys.exit(0 if success else 1)

