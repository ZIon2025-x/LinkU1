#!/usr/bin/env python3
"""
测试用户等级和任务等级分布
"""

from app.database import sync_engine
from sqlalchemy import text

def main():
    with sync_engine.connect() as conn:
        # 检查用户等级分布
        result = conn.execute(text('SELECT user_level, COUNT(*) FROM users GROUP BY user_level'))
        print('用户等级分布:')
        for row in result:
            print(f'  {row[0]}: {row[1]}人')
        
        print()
        
        # 检查任务等级分布
        result = conn.execute(text('SELECT task_level, COUNT(*) FROM tasks GROUP BY task_level'))
        print('任务等级分布:')
        for row in result:
            print(f'  {row[0]}: {row[1]}个')
        
        print()
        
        # 检查具体用户和任务
        result = conn.execute(text('SELECT id, name, user_level FROM users LIMIT 5'))
        print('用户示例:')
        for row in result:
            print(f'  ID: {row[0]}, 姓名: {row[1]}, 等级: {row[2]}')
        
        print()
        
        result = conn.execute(text('SELECT id, title, task_level FROM tasks LIMIT 5'))
        print('任务示例:')
        for row in result:
            print(f'  ID: {row[0]}, 标题: {row[1]}, 等级: {row[2]}')

if __name__ == "__main__":
    main()
