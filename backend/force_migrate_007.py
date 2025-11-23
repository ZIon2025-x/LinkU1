#!/usr/bin/env python3
"""
强制重新执行迁移 007_add_multi_participant_tasks.sql
删除迁移记录并重新执行
"""

import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent))

from app.database import sync_engine
from app.db_migrations import (
    execute_sql_file,
    is_migration_executed,
    mark_migration_executed,
    run_specific_migration
)
from sqlalchemy import text
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

MIGRATION_NAME = "007_add_multi_participant_tasks.sql"


def force_migrate():
    """强制重新执行迁移"""
    logger.info("开始强制重新执行迁移...")
    
    # 删除迁移记录（如果存在）
    try:
        with sync_engine.connect() as conn:
            result = conn.execute(
                text("DELETE FROM schema_migrations WHERE migration_name = :name"),
                {"name": MIGRATION_NAME}
            )
            conn.commit()
            if result.rowcount > 0:
                logger.info(f"✅ 已删除迁移记录: {MIGRATION_NAME}")
            else:
                logger.info(f"ℹ️  迁移记录不存在: {MIGRATION_NAME}")
    except Exception as e:
        logger.warning(f"删除迁移记录时出错: {e}")
    
    # 强制重新执行迁移
    logger.info(f"🔄 强制重新执行迁移: {MIGRATION_NAME}")
    success = run_specific_migration(sync_engine, MIGRATION_NAME, force=True)
    
    if success:
        logger.info("✅ 迁移执行成功！")
        return True
    else:
        logger.error("❌ 迁移执行失败！")
        return False


if __name__ == "__main__":
    success = force_migrate()
    sys.exit(0 if success else 1)

