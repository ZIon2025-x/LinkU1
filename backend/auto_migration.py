#!/usr/bin/env python3
"""
自动数据库迁移脚本 - 在应用启动时自动执行
"""

import os
import sys
import json
from datetime import datetime

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def migrate_job_positions():
    """迁移岗位数据"""
    try:
        from app.database import SessionLocal
        from sqlalchemy import text
        
        # 创建数据库连接
        db = SessionLocal()
        
        # 1. 检查表是否存在
        result = db.execute(text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'job_positions'
            )
        """))
        table_exists = result.scalar()
        
        if not table_exists:
            print("📝 创建 job_positions 表...")
            # 创建表
            create_table_sql = """
            CREATE TABLE job_positions (
                id SERIAL PRIMARY KEY,
                title VARCHAR(100) NOT NULL,
                title_en VARCHAR(100),
                department VARCHAR(50) NOT NULL,
                department_en VARCHAR(50),
                type VARCHAR(20) NOT NULL,
                type_en VARCHAR(20),
                location VARCHAR(100) NOT NULL,
                location_en VARCHAR(100),
                experience VARCHAR(50) NOT NULL,
                experience_en VARCHAR(50),
                salary VARCHAR(50) NOT NULL,
                salary_en VARCHAR(50),
                description TEXT NOT NULL,
                description_en TEXT,
                requirements TEXT NOT NULL,
                requirements_en TEXT,
                tags TEXT,
                tags_en TEXT,
                is_active INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_by VARCHAR(5) NOT NULL
            )
            """
            db.execute(text(create_table_sql))
            db.commit()
            print("✅ 表创建成功")
        
        # 2. 检查是否有数据
        result = db.execute(text("SELECT COUNT(*) FROM job_positions"))
        count = result.scalar()
        
        if count == 0:
            print("🌱 插入示例岗位数据...")
            
            # 示例岗位数据
            positions_data = [
                {
                    "title": "前端开发工程师",
                    "title_en": "Frontend Developer",
                    "department": "技术部",
                    "department_en": "Technology",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "3-5年",
                    "experience_en": "3-5 years",
                    "salary": "15-25K",
                    "salary_en": "15-25K",
                    "description": "负责平台前端开发，参与产品设计和用户体验优化",
                    "description_en": "Responsible for frontend development, participating in product design and user experience optimization",
                    "requirements": ["熟练掌握 React、Vue 等前端框架","熟悉 TypeScript、ES6+ 语法","有移动端开发经验优先","具备良好的代码规范和团队协作能力"],
                    "requirements_en": ["Proficient in React, Vue and other frontend frameworks","Familiar with TypeScript, ES6+ syntax","Mobile development experience preferred","Good code standards and team collaboration skills"],
                    "tags": ["React", "TypeScript", "Vue", "前端"],
                    "tags_en": ["React", "TypeScript", "Vue", "Frontend"],
                    "is_active": True,
                    "created_by": "A6688"
                },
                {
                    "title": "后端开发工程师",
                    "title_en": "Backend Developer",
                    "department": "技术部",
                    "department_en": "Technology",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "3-5年",
                    "experience_en": "3-5 years",
                    "salary": "18-30K",
                    "salary_en": "18-30K",
                    "description": "负责平台后端开发，API设计和数据库优化",
                    "description_en": "Responsible for backend development, API design and database optimization",
                    "requirements": ["熟练掌握 Python 及相关框架","熟悉 FastAPI、Django 等 Web 框架","有数据库设计和优化经验","了解微服务架构和云服务"],
                    "requirements_en": ["Proficient in Python and related frameworks","Familiar with FastAPI, Django and other Web frameworks","Database design and optimization experience","Understanding of microservices architecture and cloud services"],
                    "tags": ["Python", "FastAPI", "PostgreSQL", "Redis"],
                    "tags_en": ["Python", "FastAPI", "PostgreSQL", "Redis"],
                    "is_active": True,
                    "created_by": "A6688"
                },
                {
                    "title": "产品经理",
                    "title_en": "Product Manager",
                    "department": "产品部",
                    "department_en": "Product",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "2-4年",
                    "experience_en": "2-4 years",
                    "salary": "12-20K",
                    "salary_en": "12-20K",
                    "description": "负责产品规划和设计，用户需求分析和产品迭代",
                    "description_en": "Responsible for product planning and design, user requirement analysis and product iteration",
                    "requirements": ["有互联网产品经验","熟悉产品设计流程","具备数据分析能力","有平台类产品经验优先"],
                    "requirements_en": ["Internet product experience","Familiar with product design process","Data analysis capabilities","Platform product experience preferred"],
                    "tags": ["产品设计", "用户研究", "数据分析", "产品"],
                    "tags_en": ["Product Design", "User Research", "Data Analysis", "Product"],
                    "is_active": True,
                    "created_by": "A6688"
                },
                {
                    "title": "UI/UX设计师",
                    "title_en": "UI/UX Designer",
                    "department": "设计部",
                    "department_en": "Design",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "2-4年",
                    "experience_en": "2-4 years",
                    "salary": "10-18K",
                    "salary_en": "10-18K",
                    "description": "负责产品界面设计和用户体验优化，参与产品原型设计",
                    "description_en": "Responsible for product interface design and user experience optimization, participating in product prototyping",
                    "requirements": ["熟练使用 Figma、Sketch 等设计工具","有移动端和Web端设计经验","了解用户体验设计原则","具备良好的审美和沟通能力"],
                    "requirements_en": ["Proficient in Figma, Sketch and other design tools","Mobile and Web design experience","Understanding of UX design principles","Good aesthetic sense and communication skills"],
                    "tags": ["UI设计", "UX设计", "Figma", "原型设计"],
                    "tags_en": ["UI Design", "UX Design", "Figma", "Prototyping"],
                    "is_active": True,
                    "created_by": "A6688"
                },
                {
                    "title": "运营专员",
                    "title_en": "Operations Specialist",
                    "department": "运营部",
                    "department_en": "Operations",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "1-3年",
                    "experience_en": "1-3 years",
                    "salary": "8-15K",
                    "salary_en": "8-15K",
                    "description": "负责平台运营推广，用户增长和内容运营",
                    "description_en": "Responsible for platform operation and promotion, user growth and content operation",
                    "requirements": ["有互联网运营经验","熟悉社交媒体运营","具备数据分析能力","有用户增长经验优先"],
                    "requirements_en": ["Internet operation experience","Familiar with social media operation","Data analysis capabilities","User growth experience preferred"],
                    "tags": ["运营", "推广", "用户增长", "内容运营"],
                    "tags_en": ["Operations", "Promotion", "User Growth", "Content Operation"],
                    "is_active": True,
                    "created_by": "A6688"
                },
                {
                    "title": "客服专员",
                    "title_en": "Customer Service Specialist",
                    "department": "客服部",
                    "department_en": "Customer Service",
                    "type": "全职",
                    "type_en": "Full-time",
                    "location": "线上",
                    "location_en": "Remote",
                    "experience": "1-2年",
                    "experience_en": "1-2 years",
                    "salary": "6-12K",
                    "salary_en": "6-12K",
                    "description": "负责用户咨询和问题解答，维护客户关系",
                    "description_en": "Responsible for user consultation and problem solving, maintaining customer relationships",
                    "requirements": ["良好的沟通能力和服务意识","熟悉客服工作流程","具备耐心和责任心","有在线客服经验优先"],
                    "requirements_en": ["Good communication skills and service awareness","Familiar with customer service workflow","Patience and responsibility","Online customer service experience preferred"],
                    "tags": ["客服", "沟通", "问题解决", "客户关系"],
                    "tags_en": ["Customer Service", "Communication", "Problem Solving", "Customer Relations"],
                    "is_active": True,
                    "created_by": "A6688"
                }
            ]
            
            # 插入数据
            for pos_data in positions_data:
                insert_sql = """
                INSERT INTO job_positions (
                    title, title_en, department, department_en, type, type_en,
                    location, location_en, experience, experience_en, salary, salary_en,
                    description, description_en, requirements, requirements_en,
                    tags, tags_en, is_active, created_by
                ) VALUES (
                    :title, :title_en, :department, :department_en, :type, :type_en,
                    :location, :location_en, :experience, :experience_en, :salary, :salary_en,
                    :description, :description_en, :requirements, :requirements_en,
                    :tags, :tags_en, :is_active, :created_by
                )
                """
                
                # 处理JSON字段
                processed_data = {
                    **pos_data,
                    'requirements': json.dumps(pos_data['requirements'], ensure_ascii=False),
                    'requirements_en': json.dumps(pos_data['requirements_en'], ensure_ascii=False),
                    'tags': json.dumps(pos_data['tags'], ensure_ascii=False),
                    'tags_en': json.dumps(pos_data['tags_en'], ensure_ascii=False),
                    'is_active': 1 if pos_data['is_active'] else 0
                }
                
                db.execute(text(insert_sql), processed_data)
            
            db.commit()
            print(f"✅ 成功插入 {len(positions_data)} 个岗位数据")
        else:
            print(f"✅ 岗位数据已存在 ({count} 条记录)")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"❌ 自动迁移失败: {e}")
        return False

if __name__ == "__main__":
    print("🚀 自动数据库迁移...")
    success = migrate_job_positions()
    if success:
        print("✅ 迁移完成！")
    else:
        print("❌ 迁移失败！")
