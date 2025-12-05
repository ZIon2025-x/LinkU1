"""
初始化大学数据脚本
从 scripts/university_email_domains.json 导入大学数据到数据库
"""

import json
import sys
import os
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from app.database import SessionLocal
from app import models
from sqlalchemy.exc import IntegrityError

def init_universities():
    """初始化大学数据"""
    # 读取JSON文件
    json_path = Path(__file__).parent.parent.parent / "scripts" / "university_email_domains.json"
    
    if not json_path.exists():
        # 尝试另一个路径（如果从 app 目录调用）
        json_path = Path(__file__).parent.parent / "scripts" / "university_email_domains.json"
        if not json_path.exists():
            error_msg = f"错误：找不到文件 {json_path}"
            if hasattr(init_universities, '_logger'):
                init_universities._logger.error(error_msg)
            else:
                print(error_msg)
            return False
    
    with open(json_path, 'r', encoding='utf-8') as f:
        universities_data = json.load(f)
    
    db = SessionLocal()
    try:
        success_count = 0
        skip_count = 0
        error_count = 0
        
        for uni_data in universities_data:
            try:
                # 检查是否已存在
                existing = db.query(models.University).filter(
                    models.University.email_domain == uni_data['email_domain']
                ).first()
                
                if existing:
                    print(f"跳过：{uni_data['name']} ({uni_data['email_domain']}) - 已存在")
                    skip_count += 1
                    continue
                
                # 创建新记录
                university = models.University(
                    name=uni_data['name'],
                    name_cn=uni_data.get('name_cn'),
                    email_domain=uni_data['email_domain'],
                    domain_pattern=uni_data.get('domain_pattern', f"@{uni_data['email_domain']}"),
                    is_active=True
                )
                
                db.add(university)
                db.commit()
                print(f"✓ 添加：{uni_data['name']} ({uni_data['email_domain']})")
                success_count += 1
                
            except IntegrityError as e:
                db.rollback()
                print(f"✗ 错误：{uni_data['name']} - {str(e)}")
                error_count += 1
            except Exception as e:
                db.rollback()
                print(f"✗ 错误：{uni_data['name']} - {str(e)}")
                error_count += 1
        
        print(f"\n完成！成功：{success_count}，跳过：{skip_count}，错误：{error_count}")
        return True
        
    except Exception as e:
        print(f"初始化失败：{e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    print("开始初始化大学数据...")
    success = init_universities()
    sys.exit(0 if success else 1)

