"""
在 Railway 部署后自动创建索引
在 Railway 部署时运行此脚本
"""
import os
import sys
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

def create_indexes():
    """创建 pg_trgm 索引"""
    
    # 从环境变量获取数据库连接
    database_url = os.getenv('DATABASE_URL')
    
    if not database_url:
        print("❌ 未找到 DATABASE_URL 环境变量")
        return False
    
    try:
        # 连接数据库
        conn = psycopg2.connect(database_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        print("📦 正在创建 PostgreSQL 索引...")
        
        # 1. 确保扩展已安装
        cursor.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
        print("✅ pg_trgm 扩展已安装")
        
        # 2. 创建索引
        indexes = [
            ("idx_tasks_title_trgm", "tasks", "gin(title gin_trgm_ops)"),
            ("idx_tasks_description_trgm", "tasks", "gin(description gin_trgm_ops)"),
            ("idx_tasks_type_trgm", "tasks", "gin(task_type gin_trgm_ops)"),
            ("idx_tasks_location_trgm", "tasks", "gin(location gin_trgm_ops)"),
            ("idx_users_name_trgm", "users", "gin(name gin_trgm_ops)"),
            ("idx_users_email_trgm", "users", "gin(email gin_trgm_ops)"),
        ]
        
        for index_name, table_name, index_def in indexes:
            try:
                cursor.execute(f"CREATE INDEX IF NOT EXISTS {index_name} ON {table_name} USING {index_def};")
                print(f"✅ 创建索引: {index_name}")
            except Exception as e:
                print(f"⚠️  索引 {index_name} 可能已存在: {e}")
        
        # 3. 验证索引创建
        cursor.execute("""
            SELECT schemaname, tablename, indexname 
            FROM pg_indexes 
            WHERE indexname LIKE '%_trgm'
            ORDER BY tablename, indexname;
        """)
        
        results = cursor.fetchall()
        print("\n📊 已创建的索引:")
        for row in results:
            print(f"  - {row[1]}.{row[2]}")
        
        cursor.close()
        conn.close()
        
        print("\n✅ 索引创建完成！")
        return True
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

if __name__ == "__main__":
    create_indexes()

