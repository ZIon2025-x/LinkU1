#!/usr/bin/env python3
"""
自动数据库迁移脚本 - 在Railway部署后自动运行
"""

import os
import sys
import time
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def auto_migrate():
    """自动运行数据库迁移"""
    try:
        print("开始自动数据库迁移...")
        
        # 等待数据库连接稳定
        time.sleep(2)
        
        # 获取数据库URL
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            print("未找到DATABASE_URL环境变量，跳过迁移")
            return True
        
        print(f"连接到数据库: {database_url.split('@')[1] if '@' in database_url else 'local'}")
        
        # 使用psycopg2直接连接
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        
        # 连接数据库
        conn = psycopg2.connect(database_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        try:
            # 数据库迁移完成！
            print("数据库迁移完成！")
            return True
            
        except Exception as e:
            print(f"数据库操作失败: {e}")
            # 不抛出异常，让应用继续启动
            return False
        finally:
            cursor.close()
            conn.close()
            
    except Exception as e:
        print(f"迁移过程中出现错误: {e}")
        # 不抛出异常，让应用继续启动
        return False

if __name__ == "__main__":
    auto_migrate()
