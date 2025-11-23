#!/usr/bin/env python3
"""
检查迁移 007_add_multi_participant_tasks.sql 是否真正成功执行
验证数据库字段是否存在
"""

import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent))

from app.database import sync_engine
from sqlalchemy import text, inspect
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 需要检查的字段
REQUIRED_COLUMNS = [
    'is_multi_participant',
    'is_official_task',
    'max_participants',
    'min_participants',
    'current_participants',
    'completion_rule',
    'reward_distribution',
    'reward_type',
    'points_reward',
    'auto_accept',
    'allow_negotiation',
    'created_by_admin',
    'admin_creator_id',
    'created_by_expert',
    'expert_creator_id',
    'expert_service_id',
    'is_fixed_time_slot',
    'time_slot_duration_minutes',
    'time_slot_start_time',
    'time_slot_end_time',
    'participants_per_slot',
    'original_price_per_participant',
    'discount_percentage',
    'discounted_price_per_participant',
    'updated_at',
]

# 需要检查的表
REQUIRED_TABLES = [
    'task_participants',
    'task_participant_rewards',
    'task_audit_logs',
]


def check_migration():
    """检查迁移是否真正成功执行"""
    logger.info("开始检查迁移状态...")
    
    inspector = inspect(sync_engine)
    
    # 检查 tasks 表的字段
    logger.info("检查 tasks 表的字段...")
    tasks_columns = [col['name'] for col in inspector.get_columns('tasks')]
    missing_columns = []
    
    for col in REQUIRED_COLUMNS:
        if col not in tasks_columns:
            missing_columns.append(col)
            logger.error(f"❌ 缺少字段: {col}")
        else:
            logger.info(f"✅ 字段存在: {col}")
    
    # 检查新表
    logger.info("检查新表...")
    all_tables = inspector.get_table_names()
    missing_tables = []
    
    for table in REQUIRED_TABLES:
        if table not in all_tables:
            missing_tables.append(table)
            logger.error(f"❌ 缺少表: {table}")
        else:
            logger.info(f"✅ 表存在: {table}")
    
    # 检查迁移记录
    logger.info("检查迁移记录...")
    try:
        with sync_engine.connect() as conn:
            result = conn.execute(
                text("SELECT 1 FROM schema_migrations WHERE migration_name = :name"),
                {"name": "007_add_multi_participant_tasks.sql"}
            )
            record_exists = result.fetchone() is not None
            if record_exists:
                logger.info("✅ 迁移记录存在")
            else:
                logger.warning("⚠️  迁移记录不存在")
    except Exception as e:
        logger.error(f"检查迁移记录时出错: {e}")
        record_exists = False
    
    # 总结
    logger.info("\n" + "="*50)
    logger.info("检查结果总结:")
    logger.info(f"缺少字段数: {len(missing_columns)}")
    logger.info(f"缺少表数: {len(missing_tables)}")
    logger.info(f"迁移记录存在: {record_exists}")
    
    if missing_columns or missing_tables:
        logger.error("\n❌ 迁移未完全执行！")
        if record_exists:
            logger.warning("⚠️  迁移记录存在，但字段/表缺失，需要强制重新执行迁移")
        return False
    else:
        logger.info("\n✅ 迁移已完全执行！")
        return True


if __name__ == "__main__":
    success = check_migration()
    sys.exit(0 if success else 1)

