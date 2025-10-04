#!/usr/bin/env python3
"""
创建测试用的不同等级用户和任务
"""

import sys
import os
sys.path.append('.')

from app.database import sync_engine
from app.models import User, Task
from app.security import get_password_hash
from sqlalchemy.orm import sessionmaker
from datetime import datetime, timedelta

def create_test_data():
    Session = sessionmaker(bind=sync_engine)
    db = Session()
    
    try:
        # 创建不同等级的用户
        users = [
            {
                'id': 'test001',
                'name': '普通用户',
                'email': 'normal@test.com',
                'user_level': 'normal',
                'hashed_password': get_password_hash('123456'),
                'is_verified': 1,
                'is_active': 1,
                'created_at': datetime.utcnow()
            },
            {
                'id': 'test002', 
                'name': 'VIP用户',
                'email': 'vip@test.com',
                'user_level': 'vip',
                'hashed_password': get_password_hash('123456'),
                'is_verified': 1,
                'is_active': 1,
                'created_at': datetime.utcnow()
            },
            {
                'id': 'test003',
                'name': '超级VIP用户', 
                'email': 'super@test.com',
                'user_level': 'super',
                'hashed_password': get_password_hash('123456'),
                'is_verified': 1,
                'is_active': 1,
                'created_at': datetime.utcnow()
            }
        ]
        
        # 删除已存在的测试用户
        for user_data in users:
            existing_user = db.query(User).filter(User.id == user_data['id']).first()
            if existing_user:
                db.delete(existing_user)
        
        # 创建用户
        for user_data in users:
            user = User(**user_data)
            db.add(user)
            print(f"创建用户: {user_data['name']} ({user_data['user_level']})")
        
        # 创建不同等级的任务
        tasks = [
            {
                'title': '普通任务 - 打扫卫生',
                'description': '需要打扫办公室卫生',
                'task_level': 'normal',
                'task_type': '清洁',
                'location': '伦敦',
                'reward': 50.0,
                'deadline': datetime.utcnow() + timedelta(days=7),
                'poster_id': 'test001',
                'status': 'open',
                'created_at': datetime.utcnow()
            },
            {
                'title': 'VIP任务 - 高级编程',
                'description': '需要开发复杂的Web应用',
                'task_level': 'vip',
                'task_type': '编程',
                'location': '伦敦',
                'reward': 500.0,
                'deadline': datetime.utcnow() + timedelta(days=14),
                'poster_id': 'test002',
                'status': 'open',
                'created_at': datetime.utcnow()
            },
            {
                'title': '超级VIP任务 - 系统架构设计',
                'description': '需要设计大型分布式系统架构',
                'task_level': 'super',
                'task_type': '设计',
                'location': '伦敦',
                'reward': 2000.0,
                'deadline': datetime.utcnow() + timedelta(days=30),
                'poster_id': 'test003',
                'status': 'open',
                'created_at': datetime.utcnow()
            }
        ]
        
        # 删除已存在的测试任务
        for task_data in tasks:
            existing_task = db.query(Task).filter(Task.title == task_data['title']).first()
            if existing_task:
                db.delete(existing_task)
        
        # 创建任务
        for task_data in tasks:
            task = Task(**task_data)
            db.add(task)
            print(f"创建任务: {task_data['title']} ({task_data['task_level']})")
        
        db.commit()
        print("\n测试数据创建完成！")
        
        # 显示创建的数据
        print("\n用户列表:")
        users = db.query(User).filter(User.id.like('test%')).all()
        for user in users:
            print(f"  {user.name} - {user.user_level}")
        
        print("\n任务列表:")
        tasks = db.query(Task).filter(Task.title.like('%任务%')).all()
        for task in tasks:
            print(f"  {task.title} - {task.task_level}")
            
    except Exception as e:
        print(f"错误: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    create_test_data()
