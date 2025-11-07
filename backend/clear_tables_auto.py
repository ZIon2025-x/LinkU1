"""
自动清空数据库表脚本 - 部署时使用
修复了 Windows GBK 编码问题
"""
import os
import sys
from sqlalchemy import create_engine, text

# 设置 UTF-8 编码输出（修复 Windows GBK 问题）
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# 从环境变量获取数据库连接
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print("[ERROR] DATABASE_URL environment variable not found")
    print("[INFO] Please set DATABASE_URL in Railway environment variables")
    sys.exit(1)

# 需要清空的表列表（按依赖顺序）
TABLES_TO_CLEAR = [
    "task_applications",      # 依赖 tasks
    "reviews",               # 依赖 tasks
    "task_history",          # 依赖 tasks
    "task_cancel_requests",  # 依赖 tasks
    "messages",              # 独立表
    "notifications",         # 独立表
    "tasks",                 # 最后清空
]

def clear_tables():
    """清空指定的表"""
    try:
        print("[INFO] Starting to clear database tables...")
        db_info = DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else 'local'
        print(f"[INFO] Database: {db_info}")
        print(f"[INFO] Will clear {len(TABLES_TO_CLEAR)} tables\n")
        
        # 创建数据库连接
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            success_count = 0
            for table in TABLES_TO_CLEAR:
                try:
                    # 使用 TRUNCATE CASCADE 清空表
                    conn.execute(text(f"TRUNCATE TABLE {table} CASCADE"))
                    conn.commit()
                    print(f"[SUCCESS] Cleared: {table}")
                    success_count += 1
                except Exception as e:
                    print(f"[ERROR] Failed to clear {table}: {e}")
                    conn.rollback()
        
        print(f"\n[SUCCESS] Completed! Cleared {success_count}/{len(TABLES_TO_CLEAR)} tables")
        print("\n[INFO] The following tables were preserved:")
        print("   - users (user base information)")
        print("   - admin_users (admin accounts)")
        print("   - system_settings (system settings)")
        print("   - pending_users (pending users)")
        print("   - customer_service* (customer service tables)")
        print("   - admin_* (admin related tables)")
        print("   - user_preferences (user preferences)")
        
    except Exception as e:
        print(f"[ERROR] Database connection failed: {e}")
        print("\n[INFO] Possible reasons:")
        print("   1. DATABASE_URL format is incorrect")
        print("   2. Database service is not running")
        print("   3. Network connection issue")
        print("   4. Database credentials are wrong")
        sys.exit(1)

if __name__ == "__main__":
    clear_tables()

