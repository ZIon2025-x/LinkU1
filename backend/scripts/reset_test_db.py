"""
重置 test 环境数据库的脚本

这个脚本会：
1. 清空 schema_migrations 表（删除所有迁移记录）
2. 删除所有现有表
3. 让应用重新创建所有表和执行所有迁移

⚠️ 警告：这会删除所有数据，仅用于 test 环境！
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root / "backend"))

def reset_database():
    """重置数据库"""
    from app.database import sync_engine
    from sqlalchemy import text, inspect

    print("🔍 正在检查数据库状态...")

    # 获取所有表名
    inspector = inspect(sync_engine)
    all_tables = inspector.get_table_names()

    print(f"📊 找到 {len(all_tables)} 个表")
    print(f"表列表: {', '.join(all_tables[:10])}{'...' if len(all_tables) > 10 else ''}")

    # 确认操作
    env = os.getenv("RAILWAY_ENVIRONMENT", "unknown")
    print(f"\n⚠️  当前环境: {env}")
    print(f"⚠️  数据库 URL: {os.getenv('DATABASE_URL', '未设置')[:50]}...")

    if env.lower() == "production":
        print("\n❌ 错误：不能在生产环境执行此脚本！")
        return False

    confirm = input("\n⚠️  这将删除所有表和数据！确认继续吗? (输入 'YES' 继续): ")
    if confirm != "YES":
        print("❌ 操作已取消")
        return False

    print("\n🔄 开始重置数据库...")

    with sync_engine.connect() as conn:
        # 1. 首先清空 schema_migrations 表（如果存在）
        try:
            result = conn.execute(text("SELECT COUNT(*) FROM schema_migrations"))
            count = result.scalar()
            print(f"\n📝 schema_migrations 表中有 {count} 条记录")

            conn.execute(text("TRUNCATE TABLE schema_migrations"))
            conn.commit()
            print("✅ 已清空 schema_migrations 表")
        except Exception as e:
            print(f"ℹ️  schema_migrations 表不存在或已为空: {e}")

        # 2. 删除所有表（使用 CASCADE）
        if all_tables:
            print(f"\n🗑️  正在删除 {len(all_tables)} 个表...")
            try:
                # 先禁用外键约束
                conn.execute(text("SET session_replication_role = 'replica';"))

                # 删除所有表
                for table in all_tables:
                    try:
                        conn.execute(text(f'DROP TABLE IF EXISTS "{table}" CASCADE'))
                        print(f"  ✓ 已删除表: {table}")
                    except Exception as e:
                        print(f"  ⚠️  删除表 {table} 失败: {e}")

                # 恢复外键约束
                conn.execute(text("SET session_replication_role = 'origin';"))

                conn.commit()
                print("✅ 所有表已删除")
            except Exception as e:
                conn.rollback()
                print(f"❌ 删除表时出错: {e}")
                return False

        # 3. 验证
        inspector = inspect(sync_engine)
        remaining_tables = inspector.get_table_names()

        if remaining_tables:
            print(f"\n⚠️  仍有 {len(remaining_tables)} 个表未删除: {remaining_tables}")
        else:
            print("\n✅ 数据库已完全清空")

    print("\n" + "="*60)
    print("✅ 数据库重置完成！")
    print("="*60)
    print("\n📋 下一步操作：")
    print("1. 重新部署 test 环境（或重启应用）")
    print("2. 应用会自动创建所有表并执行所有迁移")
    print("3. 检查日志确认所有迁移都成功执行")

    return True


if __name__ == "__main__":
    print("="*60)
    print("数据库重置脚本")
    print("="*60)

    # 检查环境变量
    if not os.getenv("DATABASE_URL"):
        print("\n❌ 错误：未设置 DATABASE_URL 环境变量")
        print("请确保已加载正确的环境配置")
        sys.exit(1)

    # 执行重置
    success = reset_database()

    if success:
        print("\n✅ 脚本执行成功")
        sys.exit(0)
    else:
        print("\n❌ 脚本执行失败")
        sys.exit(1)
