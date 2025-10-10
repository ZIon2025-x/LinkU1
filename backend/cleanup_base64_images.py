#!/usr/bin/env python3
"""
清理数据库中的旧base64格式图片消息
"""

import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from sqlalchemy import create_engine, text
from app.database import DATABASE_URL

def cleanup_base64_images():
    """清理base64格式的图片消息"""
    try:
        print("正在连接数据库...")
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            
            try:
                # 统计base64图片消息数量
                print("统计base64图片消息...")
                
                # 普通消息表
                result = conn.execute(text("""
                    SELECT COUNT(*) FROM messages 
                    WHERE content LIKE 'data:image/%'
                """))
                base64_count = result.scalar()
                
                # 客服消息表
                result = conn.execute(text("""
                    SELECT COUNT(*) FROM customer_service_messages 
                    WHERE content LIKE 'data:image/%'
                """))
                cs_base64_count = result.scalar()
                
                total_base64 = base64_count + cs_base64_count
                
                print(f"发现 {base64_count} 条普通消息使用base64格式")
                print(f"发现 {cs_base64_count} 条客服消息使用base64格式")
                print(f"总计: {total_base64} 条消息需要处理")
                
                if total_base64 == 0:
                    print("没有发现base64格式的图片消息")
                    trans.rollback()
                    return
                
                # 询问用户是否继续
                response = input("\n是否要删除这些旧格式的图片消息？(yes/no): ")
                if response.lower() != 'yes':
                    print("操作已取消")
                    trans.rollback()
                    return
                
                # 删除base64格式的消息
                print("删除base64格式的消息...")
                
                # 删除普通消息
                if base64_count > 0:
                    conn.execute(text("""
                        DELETE FROM messages 
                        WHERE content LIKE 'data:image/%'
                    """))
                    print(f"已删除 {base64_count} 条普通消息")
                
                # 删除客服消息
                if cs_base64_count > 0:
                    conn.execute(text("""
                        DELETE FROM customer_service_messages 
                        WHERE content LIKE 'data:image/%'
                    """))
                    print(f"已删除 {cs_base64_count} 条客服消息")
                
                # 提交事务
                trans.commit()
                print(f"\n✅ 成功清理 {total_base64} 条旧格式图片消息")
                print("提示: 用户需要重新发送这些图片")
                
            except Exception as e:
                trans.rollback()
                print(f"❌ 清理失败: {e}")
                raise
                
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("=" * 60)
    print("Base64图片消息清理工具")
    print("=" * 60)
    print()
    print("此工具将删除数据库中使用旧base64格式存储的图片消息")
    print("警告: 此操作不可逆！")
    print()
    
    cleanup_base64_images()

