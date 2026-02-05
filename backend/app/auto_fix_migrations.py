"""
自动检测并修复迁移状态不一致的问题

在应用启动时自动运行，通过环境变量控制：
- RESET_MIGRATIONS=true: 清空迁移记录，重新执行所有迁移
- FIX_MIGRATIONS=true: 智能检测并修复（推荐）
"""

import os
import logging
from sqlalchemy import text, inspect
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)


def check_migration_consistency(engine: Engine) -> dict:
    """
    检查迁移状态一致性

    Returns:
        {
            'has_schema_migrations': bool,
            'migration_count': int,
            'table_count': int,
            'has_critical_tables': bool,
            'missing_tables': list,
            'needs_fix': bool
        }
    """
    inspector = inspect(engine)
    all_tables = inspector.get_table_names()

    # 关键表列表
    critical_tables = [
        'users', 'tasks', 'universities', 'notifications',
        'messages', 'conversations', 'reviews'
    ]

    missing_tables = [t for t in critical_tables if t not in all_tables]
    has_critical_tables = len(missing_tables) == 0

    result = {
        'has_schema_migrations': 'schema_migrations' in all_tables,
        'migration_count': 0,
        'table_count': len(all_tables),
        'has_critical_tables': has_critical_tables,
        'missing_tables': missing_tables,
        'needs_fix': False
    }

    # 检查迁移记录数
    if result['has_schema_migrations']:
        try:
            with engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM schema_migrations"))
                result['migration_count'] = res.scalar()
        except Exception as e:
            logger.warning(f"无法读取迁移记录: {e}")

    # 判断是否需要修复
    # 如果有迁移记录但缺少关键表，说明状态不一致
    if result['migration_count'] > 0 and not has_critical_tables:
        result['needs_fix'] = True
        logger.warning(f"⚠️  检测到状态不一致: 有 {result['migration_count']} 条迁移记录，但缺少 {len(missing_tables)} 个关键表")

    return result


def reset_migration_records(engine: Engine):
    """清空迁移记录表"""
    try:
        with engine.connect() as conn:
            # 检查表是否存在
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_name = 'schema_migrations'
                )
            """))

            if result.scalar():
                # 先查看有多少记录
                count_result = conn.execute(text("SELECT COUNT(*) FROM schema_migrations"))
                count = count_result.scalar()

                # 清空表
                conn.execute(text("TRUNCATE TABLE schema_migrations"))
                conn.commit()

                logger.info(f"✅ 已清空 schema_migrations 表 ({count} 条记录)")
                return True
            else:
                logger.info("ℹ️  schema_migrations 表不存在，无需清空")
                return False

    except Exception as e:
        logger.error(f"❌ 清空迁移记录失败: {e}")
        return False


def auto_fix_migrations(engine: Engine, force_reset: bool = False):
    """
    自动修复迁移状态

    Args:
        engine: 数据库引擎
        force_reset: 是否强制重置（清空迁移记录）
    """
    # 检查环境
    env = os.getenv("RAILWAY_ENVIRONMENT", os.getenv("ENVIRONMENT", "development"))

    logger.info("="*60)
    logger.info("🔍 开始检查迁移状态")
    logger.info(f"📌 当前环境: {env}")
    logger.info("="*60)

    # 检查状态
    status = check_migration_consistency(engine)

    logger.info(f"📊 数据库状态:")
    logger.info(f"  • 表总数: {status['table_count']}")
    logger.info(f"  • 迁移记录数: {status['migration_count']}")
    logger.info(f"  • 关键表完整: {'✅' if status['has_critical_tables'] else '❌'}")

    if status['missing_tables']:
        logger.warning(f"  • 缺少表: {', '.join(status['missing_tables'][:5])}")

    # 判断是否需要修复
    should_fix = False

    if force_reset:
        logger.warning("⚠️  RESET_MIGRATIONS=true, 将强制清空迁移记录")
        should_fix = True
    elif status['needs_fix']:
        logger.warning("⚠️  检测到状态不一致，将自动修复")
        should_fix = True
    else:
        logger.info("✅ 迁移状态正常，无需修复")

    # 执行修复
    if should_fix:
        # 生产环境需要额外确认
        if env.lower() == "production":
            logger.error("❌ 生产环境不允许自动重置迁移！")
            logger.error("请手动检查并修复")
            return False

        logger.info("🔄 开始修复...")
        success = reset_migration_records(engine)

        if success:
            logger.info("✅ 修复完成！应用将重新创建表并执行所有迁移")
            logger.info("="*60)
            return True
        else:
            logger.error("❌ 修复失败")
            return False

    logger.info("="*60)
    return True


def run_auto_fix_if_needed(engine: Engine):
    """
    根据环境变量决定是否运行自动修复

    环境变量:
        RESET_MIGRATIONS=true: 强制重置迁移记录
        FIX_MIGRATIONS=true: 智能检测并修复（推荐）
    """
    # 检查是否启用自动修复
    reset_migrations = os.getenv("RESET_MIGRATIONS", "false").lower() == "true"
    fix_migrations = os.getenv("FIX_MIGRATIONS", "false").lower() == "true"

    if reset_migrations or fix_migrations:
        logger.info("🔧 自动修复已启用")
        auto_fix_migrations(engine, force_reset=reset_migrations)
    else:
        # 即使没有启用，也做一个快速检查并记录状态
        status = check_migration_consistency(engine)
        if status['needs_fix']:
            logger.warning("="*60)
            logger.warning("⚠️  检测到迁移状态不一致！")
            logger.warning(f"  • 迁移记录: {status['migration_count']} 条")
            logger.warning(f"  • 缺少关键表: {len(status['missing_tables'])} 个")
            logger.warning("")
            logger.warning("💡 建议修复方案:")
            logger.warning("  1. 在 Railway 环境变量中添加: FIX_MIGRATIONS=true")
            logger.warning("  2. 重新部署应用")
            logger.warning("  3. 修复完成后删除该环境变量")
            logger.warning("="*60)
