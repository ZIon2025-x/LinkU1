"""
自动创建 PostgreSQL 索引
在应用启动时运行此脚本
"""
import logging
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

logger = logging.getLogger(__name__)

def create_trgm_indexes(database_url: str):
    """创建 pg_trgm 索引"""
    try:
        # 连接数据库
        conn = psycopg2.connect(database_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        logger.info("📦 正在创建 PostgreSQL 索引...")
        
        # 1. 确保扩展已安装
        cursor.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
        logger.info("✅ pg_trgm 扩展已安装")
        
        # 2. 创建索引
        indexes = [
            ("idx_tasks_title_trgm", "tasks", "gin(title gin_trgm_ops)"),
            ("idx_tasks_description_trgm", "tasks", "gin(description gin_trgm_ops)"),
            ("idx_tasks_type_trgm", "tasks", "gin(task_type gin_trgm_ops)"),
            ("idx_tasks_location_trgm", "tasks", "gin(location gin_trgm_ops)"),
            ("idx_users_name_trgm", "users", "gin(name gin_trgm_ops)"),
            ("idx_users_email_trgm", "users", "gin(email gin_trgm_ops)"),
        ]
        
        created_count = 0
        for index_name, table_name, index_def in indexes:
            try:
                sql = f"CREATE INDEX IF NOT EXISTS {index_name} ON {table_name} USING {index_def};"
                cursor.execute(sql)
                created_count += 1
                logger.info(f"✅ 创建索引: {index_name}")
            except Exception as e:
                logger.warning(f"⚠️  索引 {index_name}: {e}")
        
        # 3. 验证索引创建
        cursor.execute("""
            SELECT schemaname, tablename, indexname 
            FROM pg_indexes 
            WHERE indexname LIKE '%_trgm';
        """)
        
        results = cursor.fetchall()
        logger.info(f"📊 已创建 {created_count} 个新索引，共 {len(results)} 个 trgm 索引")
        
        cursor.close()
        conn.close()
        
        logger.info("✅ 索引创建完成！")
        return True
        
    except Exception as e:
        logger.error(f"❌ 创建索引失败: {e}")
        return False

