"""
检查数据库状态的脚本

用于诊断迁移状态和实际表状态的不一致问题
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root / "backend"))


def check_database_state():
    """检查数据库状态"""
    from app.database import sync_engine
    from sqlalchemy import text, inspect

    print("="*60)
    print("数据库状态检查")
    print("="*60)

    # 环境信息
    env = os.getenv("RAILWAY_ENVIRONMENT", "unknown")
    db_url = os.getenv("DATABASE_URL", "未设置")
    print(f"\n📌 环境: {env}")
    print(f"📌 数据库: {db_url[:50]}...")

    # 1. 检查所有表
    print("\n" + "="*60)
    print("1. 数据库表检查")
    print("="*60)

    inspector = inspect(sync_engine)
    all_tables = sorted(inspector.get_table_names())

    print(f"\n找到 {len(all_tables)} 个表:\n")

    # 关键表列表
    critical_tables = [
        'users', 'tasks', 'universities', 'featured_task_experts',
        'flea_market_items', 'service_time_slots', 'task_translations',
        'device_tokens', 'notifications', 'activities'
    ]

    missing_tables = []
    existing_tables = []

    for table in critical_tables:
        if table in all_tables:
            existing_tables.append(table)
            print(f"  ✅ {table}")
        else:
            missing_tables.append(table)
            print(f"  ❌ {table} (不存在)")

    if all_tables:
        print(f"\n其他表 ({len(all_tables) - len(existing_tables)} 个):")
        other_tables = [t for t in all_tables if t not in critical_tables]
        for table in other_tables[:10]:
            print(f"  • {table}")
        if len(other_tables) > 10:
            print(f"  ... 还有 {len(other_tables) - 10} 个表")

    # 2. 检查迁移记录
    print("\n" + "="*60)
    print("2. 迁移记录检查")
    print("="*60)

    try:
        with sync_engine.connect() as conn:
            # 检查 schema_migrations 表
            if 'schema_migrations' in all_tables:
                result = conn.execute(text("""
                    SELECT COUNT(*) as total,
                           MIN(executed_at) as first_migration,
                           MAX(executed_at) as last_migration
                    FROM schema_migrations
                """))
                row = result.fetchone()

                print(f"\n✅ schema_migrations 表存在")
                print(f"  • 迁移记录数: {row[0]}")
                print(f"  • 最早迁移时间: {row[1]}")
                print(f"  • 最新迁移时间: {row[2]}")

                # 列出所有迁移记录
                result = conn.execute(text("""
                    SELECT migration_name, executed_at, execution_time_ms
                    FROM schema_migrations
                    ORDER BY migration_name
                """))

                migrations = result.fetchall()
                print(f"\n  前 10 个迁移记录:")
                for i, (name, executed_at, exec_time) in enumerate(migrations[:10], 1):
                    print(f"    {i}. {name} ({exec_time}ms)")

                if len(migrations) > 10:
                    print(f"    ... 还有 {len(migrations) - 10} 条记录")

            else:
                print("\n❌ schema_migrations 表不存在")

    except Exception as e:
        print(f"\n❌ 检查迁移记录失败: {e}")

    # 3. 检查迁移文件
    print("\n" + "="*60)
    print("3. 迁移文件检查")
    print("="*60)

    migrations_dir = project_root / "backend" / "migrations"
    if migrations_dir.exists():
        sql_files = sorted(migrations_dir.glob("*.sql"))
        print(f"\n找到 {len(sql_files)} 个迁移文件")

        print("\n  前 10 个迁移文件:")
        for i, file in enumerate(sql_files[:10], 1):
            print(f"    {i}. {file.name}")

        if len(sql_files) > 10:
            print(f"    ... 还有 {len(sql_files) - 10} 个文件")
    else:
        print(f"\n❌ 迁移目录不存在: {migrations_dir}")

    # 4. 问题诊断
    print("\n" + "="*60)
    print("4. 问题诊断")
    print("="*60)

    issues = []

    if missing_tables:
        issues.append(f"❌ 缺少 {len(missing_tables)} 个关键表")
        print(f"\n❌ 缺少关键表:")
        for table in missing_tables:
            print(f"  • {table}")

    if 'schema_migrations' in all_tables:
        try:
            with sync_engine.connect() as conn:
                result = conn.execute(text("SELECT COUNT(*) FROM schema_migrations"))
                migration_count = result.scalar()

                if migration_count > 0 and len(all_tables) < 10:
                    issues.append(f"⚠️  有 {migration_count} 条迁移记录，但只有 {len(all_tables)} 个表")
                    print(f"\n⚠️  状态不一致:")
                    print(f"  • 迁移记录: {migration_count} 条")
                    print(f"  • 实际表数: {len(all_tables)} 个")
                    print(f"  • 这表明迁移记录和实际数据库状态不同步！")
        except Exception:
            pass

    # 5. 建议
    print("\n" + "="*60)
    print("5. 修复建议")
    print("="*60)

    if issues:
        print("\n发现以下问题:")
        for issue in issues:
            print(f"  {issue}")

        print("\n建议修复方案:")
        print("\n方案一（推荐 - 完全重置）:")
        print("  1. 运行重置脚本:")
        print("     python backend/scripts/reset_test_db.py")
        print("  2. 重新部署或重启应用")
        print("  3. 应用会自动创建所有表并执行所有迁移")

        print("\n方案二（手动修复）:")
        print("  1. 清空 schema_migrations 表:")
        print("     TRUNCATE TABLE schema_migrations;")
        print("  2. 重启应用")
        print("  3. 应用会重新创建表并执行迁移")

        if env.lower() == "production":
            print("\n⚠️  警告：当前是生产环境，请谨慎操作！")
            print("建议先在 test 环境测试修复方案")
    else:
        print("\n✅ 数据库状态正常，未发现问题")

    print("\n" + "="*60)


if __name__ == "__main__":
    # 检查环境变量
    if not os.getenv("DATABASE_URL"):
        print("\n❌ 错误：未设置 DATABASE_URL 环境变量")
        print("请确保已加载正确的环境配置")
        sys.exit(1)

    check_database_state()
