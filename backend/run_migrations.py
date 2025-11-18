#!/usr/bin/env python3
"""
数据库迁移管理工具
用于手动运行数据库迁移脚本

用法:
    python run_migrations.py                    # 运行所有未执行的迁移
    python run_migrations.py --force            # 强制重新运行所有迁移
    python run_migrations.py --migration fix_conversation_key.sql  # 运行指定迁移
    python run_migrations.py --list             # 列出所有迁移脚本
    python run_migrations.py --status           # 查看迁移状态
"""
import argparse
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent))

from app.database import sync_engine
from app.db_migrations import (
    run_migrations,
    run_specific_migration,
    ensure_migration_table,
    is_migration_executed
)
from sqlalchemy import text
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def list_migrations():
    """列出所有迁移脚本"""
    from app.db_migrations import MIGRATIONS_DIR
    
    if not MIGRATIONS_DIR.exists():
        print(f"迁移目录不存在: {MIGRATIONS_DIR}")
        return
    
    sql_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    
    if not sql_files:
        print("没有找到迁移脚本")
        return
    
    print(f"\n找到 {len(sql_files)} 个迁移脚本:\n")
    
    ensure_migration_table(sync_engine)
    
    for sql_file in sql_files:
        migration_name = sql_file.name
        executed = is_migration_executed(sync_engine, migration_name)
        status = "✅ 已执行" if executed else "⏳ 未执行"
        print(f"  {status} - {migration_name}")


def show_status():
    """显示迁移状态"""
    from app.db_migrations import MIGRATIONS_DIR
    
    ensure_migration_table(sync_engine)
    
    with sync_engine.connect() as conn:
        result = conn.execute(text("""
            SELECT 
                migration_name,
                executed_at,
                execution_time_ms
            FROM schema_migrations
            ORDER BY executed_at DESC
        """))
        migrations = result.fetchall()
    
    print(f"\n已执行的迁移 ({len(migrations)} 个):\n")
    
    if not migrations:
        print("  暂无已执行的迁移")
    else:
        for migration_name, executed_at, execution_time_ms in migrations:
            print(f"  ✅ {migration_name}")
            print(f"     执行时间: {executed_at}")
            print(f"     耗时: {execution_time_ms}ms")
            print()


def main():
    parser = argparse.ArgumentParser(description="数据库迁移管理工具")
    parser.add_argument(
        "--force",
        action="store_true",
        help="强制重新运行所有迁移（即使已执行）"
    )
    parser.add_argument(
        "--migration",
        type=str,
        help="运行指定的迁移脚本（文件名）"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="列出所有迁移脚本"
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="查看迁移状态"
    )
    
    args = parser.parse_args()
    
    if args.list:
        list_migrations()
        return
    
    if args.status:
        show_status()
        return
    
    if args.migration:
        # 运行指定的迁移
        success = run_specific_migration(sync_engine, args.migration, force=args.force)
        sys.exit(0 if success else 1)
    else:
        # 运行所有迁移
        run_migrations(sync_engine, force=args.force)


if __name__ == "__main__":
    main()

