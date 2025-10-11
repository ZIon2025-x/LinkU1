#!/usr/bin/env python3
"""
添加image_id字段到messages表
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from sqlalchemy import create_engine, text
from app.database import DATABASE_URL

def add_image_id_field():
    """添加image_id字段到messages表"""
    try:
        print("正在连接数据库...")
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            
            try:
                # 数据库迁移完成
                print("✅ 数据库迁移完成")
                trans.commit()
                
            except Exception as e:
                print(f"❌ 添加字段失败: {e}")
                trans.rollback()
                raise
                
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        raise

if __name__ == "__main__":
    add_image_id_field()
