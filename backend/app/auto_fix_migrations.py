"""
自动检测并修复迁移状态不一致的问题

在应用启动时自动运行，通过环境变量控制：
- RESET_MIGRATIONS=true: 清空迁移记录，重新执行所有迁移
- FIX_MIGRATIONS=true: 智能检测并修复（推荐）
- DROP_ALL_TABLES=true: 删除所有数据库表并重新创建（⚠️ 危险：会清除所有数据）

注意：DROP_ALL_TABLES 需要与 RESET_MIGRATIONS 或 FIX_MIGRATIONS 一起使用
"""

import os
import re
import logging
from sqlalchemy import text, inspect
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)


def _safe_identifier(name: str) -> str:
    """验证并引用 PostgreSQL 标识符，防止 SQL 注入"""
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', name):
        raise ValueError(f"不安全的标识符: {name}")
    return f'"{name}"'


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
        'messages', 'reviews'
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


def reset_migration_records(engine: Engine, drop_tables: bool = False):
    """
    清空迁移记录表，可选择是否同时删除所有表

    Args:
        engine: 数据库引擎
        drop_tables: 是否同时删除所有数据库表（用于完全重置）
    """
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
            else:
                logger.info("ℹ️  schema_migrations 表不存在，无需清空")

            # 如果需要删除所有表（完全重置）
            if drop_tables:
                logger.warning("🗑️  开始删除所有数据库对象...")

                # 使用 DROP SCHEMA CASCADE 一步清空所有对象（表、索引、序列、函数、类型等）
                # 这比逐表删除更可靠，不会遗漏孤立的索引或其他对象
                try:
                    conn.execute(text("DROP SCHEMA public CASCADE"))
                    conn.execute(text("CREATE SCHEMA public"))
                    conn.execute(text("GRANT ALL ON SCHEMA public TO public"))
                    conn.commit()
                    logger.info("✅ 已重置 public schema（所有对象已删除）")
                except Exception as schema_err:
                    logger.warning(f"DROP SCHEMA 方式失败，回退到逐对象删除: {schema_err}")
                    conn.rollback()

                    # Fallback: 逐表删除
                    try:
                        tables_result = conn.execute(text("""
                            SELECT tablename FROM pg_tables
                            WHERE schemaname = 'public'
                        """))
                        all_tables = [row[0] for row in tables_result.fetchall()]

                        for table in all_tables:
                            try:
                                conn.execute(text(f'DROP TABLE IF EXISTS {_safe_identifier(table)} CASCADE'))
                            except Exception as e:
                                logger.warning(f"  删除表 {table} 失败: {e}")

                        # 清理孤立索引
                        indexes_result = conn.execute(text("""
                            SELECT c.relname FROM pg_class c
                            JOIN pg_namespace n ON n.oid = c.relnamespace
                            WHERE c.relkind = 'i' AND n.nspname = 'public'
                            AND c.relname NOT LIKE 'pg_%%'
                        """))
                        for (idx_name,) in indexes_result.fetchall():
                            try:
                                conn.execute(text(f'DROP INDEX IF EXISTS {_safe_identifier(idx_name)} CASCADE'))
                            except Exception:
                                pass

                        # 清理自定义 ENUM 类型
                        types_result = conn.execute(text("""
                            SELECT t.typname FROM pg_type t
                            JOIN pg_namespace n ON t.typnamespace = n.oid
                            WHERE n.nspname = 'public' AND t.typtype = 'e'
                        """))
                        for (type_name,) in types_result.fetchall():
                            try:
                                conn.execute(text(f'DROP TYPE IF EXISTS {_safe_identifier(type_name)} CASCADE'))
                            except Exception:
                                pass

                        conn.commit()
                        logger.info("✅ 已通过逐对象方式完成清理")
                    except Exception as fallback_err:
                        logger.error(f"逐对象清理也失败: {fallback_err}")
                        conn.rollback()

                return True

            return True

    except Exception as e:
        logger.error(f"❌ 清空迁移记录失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def _is_production_environment() -> bool:
    """
    严格的生产环境检测

    只有明确标记为 production 的环境才返回 True
    staging、testing 等环境返回 False

    Returns:
        True: 生产环境
        False: 非生产环境（开发、测试、预发布等）
    """
    env = os.getenv("ENVIRONMENT", "").lower()
    railway_env = os.getenv("RAILWAY_ENVIRONMENT", "").lower()

    return env == "production" or railway_env == "production"


def auto_fix_migrations(engine: Engine, force_reset: bool = False):
    """
    自动修复迁移状态

    Args:
        engine: 数据库引擎
        force_reset: 是否强制重置（清空迁移记录）
    """
    # 检查环境
    env = os.getenv("RAILWAY_ENVIRONMENT") or os.getenv("ENVIRONMENT") or "development"
    is_production = _is_production_environment()

    logger.info("="*60)
    logger.info("🔍 开始检查迁移状态")
    logger.info(f"📌 当前环境: {env} {'[生产环境]' if is_production else '[非生产环境]'}")
    logger.info("="*60)

    # 🔴 生产环境保护：立即拒绝任何自动修复操作
    if is_production:
        logger.error("=" * 60)
        logger.error("🚫 生产环境保护：不允许自动重置迁移或删除表！")
        logger.error("🚫 检测到环境标识：")
        logger.error(f"   - ENVIRONMENT={os.getenv('ENVIRONMENT', 'not set')}")
        logger.error(f"   - RAILWAY_ENVIRONMENT={os.getenv('RAILWAY_ENVIRONMENT', 'not set')}")
        logger.error("=" * 60)
        logger.error("如需修复生产环境，请：")
        logger.error("  1. 先备份数据库")
        logger.error("  2. 手动执行迁移脚本")
        logger.error("  3. 验证数据完整性")
        logger.error("=" * 60)
        return False

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
        logger.info("🔄 开始修复...")

        # 检查是否需要删除所有表（完全重置）
        # DROP_ALL_TABLES=true 将删除所有表并重新创建
        drop_tables = os.getenv("DROP_ALL_TABLES", "false").lower() == "true"

        if drop_tables:
            logger.warning("⚠️  DROP_ALL_TABLES=true，将删除所有数据库表！")
            logger.warning("⚠️  这将清除所有数据，请确保这是您想要的操作！")

        success = reset_migration_records(engine, drop_tables=drop_tables)

        if success:
            if drop_tables:
                logger.info("✅ 修复完成！已删除所有表，应用将重新创建表并执行所有迁移")
            else:
                logger.info("✅ 修复完成！应用将重新创建缺失的表并执行所有迁移")
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
        DROP_ALL_TABLES=true: 删除所有数据库表并重新创建（⚠️ 危险：会清除所有数据）
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
