#!/usr/bin/env python3
"""
数据库迁移管理脚本
提供便捷的迁移操作命令
"""

import os
import sys
import subprocess
import argparse
from datetime import datetime
from pathlib import Path

def run_command(command, description):
    """运行命令并显示结果"""
    print(f"\n🔄 {description}...")
    print(f"执行命令: {command}")
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"✅ {description} 成功")
            if result.stdout:
                print(f"输出:\n{result.stdout}")
        else:
            print(f"❌ {description} 失败")
            if result.stderr:
                print(f"错误:\n{result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ {description} 异常: {e}")
        return False
    
    return True

def check_database_connection():
    """检查数据库连接"""
    print("[DEBUG] 检查数据库连接...")
    
    try:
        from app.database import engine
        from sqlalchemy import text
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("✅ 数据库连接正常")
        return True
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        return False

def create_migration(message):
    """创建新的迁移"""
    if not message:
        message = input("请输入迁移描述: ")
    
    # 生成带时间戳的迁移文件名
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    migration_name = f"{timestamp}_{message.replace(' ', '_').lower()}"
    
    command = f'alembic revision --autogenerate -m "{message}"'
    return run_command(command, f"创建迁移: {message}")

def upgrade_database(revision="head"):
    """升级数据库"""
    command = f"alembic upgrade {revision}"
    return run_command(command, f"升级数据库到 {revision}")

def downgrade_database(revision="-1"):
    """降级数据库"""
    command = f"alembic downgrade {revision}"
    return run_command(command, f"降级数据库到 {revision}")

def show_migration_history():
    """显示迁移历史"""
    command = "alembic history --verbose"
    return run_command(command, "显示迁移历史")

def show_current_revision():
    """显示当前版本"""
    command = "alembic current"
    return run_command(command, "显示当前数据库版本")

def show_pending_migrations():
    """显示待执行的迁移"""
    command = "alembic heads"
    return run_command(command, "显示最新迁移版本")

def validate_migrations():
    """验证迁移文件"""
    print("[DEBUG] 验证迁移文件...")
    
    # 检查迁移文件语法
    versions_dir = Path("alembic/versions")
    if not versions_dir.exists():
        print("❌ 迁移目录不存在")
        return False
    
    migration_files = list(versions_dir.glob("*.py"))
    if not migration_files:
        print("❌ 没有找到迁移文件")
        return False
    
    print(f"✅ 找到 {len(migration_files)} 个迁移文件")
    
    # 检查最新迁移文件
    latest_migration = max(migration_files, key=lambda x: x.stat().st_mtime)
    print(f"📄 最新迁移文件: {latest_migration.name}")
    
    return True

def reset_database():
    """重置数据库（危险操作）"""
    print("⚠️  警告: 这将删除所有数据!")
    confirm = input("确认重置数据库? (输入 'YES' 确认): ")
    
    if confirm != "YES":
        print("❌ 操作已取消")
        return False
    
    # 降级到初始状态
    if not downgrade_database("base"):
        return False
    
    # 重新升级
    if not upgrade_database("head"):
        return False
    
    print("✅ 数据库重置完成")
    return True

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="数据库迁移管理工具")
    parser.add_argument("command", choices=[
        "create", "upgrade", "downgrade", "history", 
        "current", "heads", "validate", "reset", "status"
    ], help="要执行的命令")
    parser.add_argument("-m", "--message", help="迁移描述信息")
    parser.add_argument("-r", "--revision", default="head", help="目标版本")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🗄️  Link²Ur数据库迁移管理工具")
    print("=" * 60)
    
    # 检查数据库连接
    if not check_database_connection():
        print("❌ 无法连接到数据库，请检查配置")
        sys.exit(1)
    
    success = False
    
    if args.command == "create":
        success = create_migration(args.message)
    elif args.command == "upgrade":
        success = upgrade_database(args.revision)
    elif args.command == "downgrade":
        success = downgrade_database(args.revision)
    elif args.command == "history":
        success = show_migration_history()
    elif args.command == "current":
        success = show_current_revision()
    elif args.command == "heads":
        success = show_pending_migrations()
    elif args.command == "validate":
        success = validate_migrations()
    elif args.command == "reset":
        success = reset_database()
    elif args.command == "status":
        print("📊 数据库迁移状态:")
        show_current_revision()
        show_pending_migrations()
        validate_migrations()
        success = True
    
    if success:
        print("\n✅ 操作完成")
    else:
        print("\n❌ 操作失败")
        sys.exit(1)

if __name__ == "__main__":
    main()
