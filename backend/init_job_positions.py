#!/usr/bin/env python3
"""
初始化岗位数据到数据库
"""

import os
import sys
import json
from datetime import datetime

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal
from app.models import JobPosition

def init_job_positions():
    """初始化岗位数据"""
    
    # 岗位数据
    positions_data = [
        {
            "title": "前端开发工程师",
            "title_en": "Frontend Developer",
            "department": "技术部",
            "department_en": "Technology",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京/远程",
            "location_en": "Beijing/Remote",
            "experience": "3-5年",
            "experience_en": "3-5 years",
            "salary": "15-25K",
            "salary_en": "15-25K",
            "description": "负责平台前端开发，参与产品设计和用户体验优化",
            "description_en": "Responsible for frontend development, participating in product design and user experience optimization",
            "requirements": [
                "熟练掌握 React、Vue 等前端框架",
                "熟悉 TypeScript、ES6+ 语法",
                "有移动端开发经验优先",
                "具备良好的代码规范和团队协作能力"
            ],
            "requirements_en": [
                "Proficient in React, Vue and other frontend frameworks",
                "Familiar with TypeScript, ES6+ syntax",
                "Mobile development experience preferred",
                "Good code standards and team collaboration skills"
            ],
            "tags": ["React", "TypeScript", "Vue", "前端"],
            "tags_en": ["React", "TypeScript", "Vue", "Frontend"],
            "is_active": True,
            "created_by": "A0001"
        },
        {
            "title": "后端开发工程师",
            "title_en": "Backend Developer",
            "department": "技术部",
            "department_en": "Technology",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京/远程",
            "location_en": "Beijing/Remote",
            "experience": "3-5年",
            "experience_en": "3-5 years",
            "salary": "18-30K",
            "salary_en": "18-30K",
            "description": "负责平台后端开发，API设计和数据库优化",
            "description_en": "Responsible for backend development, API design and database optimization",
            "requirements": [
                "熟练掌握 Python 及相关框架",
                "熟悉 FastAPI、Django 等 Web 框架",
                "有数据库设计和优化经验",
                "了解微服务架构和云服务"
            ],
            "requirements_en": [
                "Proficient in Python and related frameworks",
                "Familiar with FastAPI, Django and other Web frameworks",
                "Database design and optimization experience",
                "Understanding of microservices architecture and cloud services"
            ],
            "tags": ["Python", "FastAPI", "PostgreSQL", "Redis"],
            "tags_en": ["Python", "FastAPI", "PostgreSQL", "Redis"],
            "is_active": True,
            "created_by": "A0001"
        },
        {
            "title": "产品经理",
            "title_en": "Product Manager",
            "department": "产品部",
            "department_en": "Product",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京",
            "location_en": "Beijing",
            "experience": "2-4年",
            "experience_en": "2-4 years",
            "salary": "12-20K",
            "salary_en": "12-20K",
            "description": "负责产品规划和设计，用户需求分析和产品迭代",
            "description_en": "Responsible for product planning and design, user requirement analysis and product iteration",
            "requirements": [
                "有互联网产品经验",
                "熟悉产品设计流程",
                "具备数据分析能力",
                "有平台类产品经验优先"
            ],
            "requirements_en": [
                "Internet product experience",
                "Familiar with product design process",
                "Data analysis capabilities",
                "Platform product experience preferred"
            ],
            "tags": ["产品设计", "用户研究", "数据分析", "产品"],
            "tags_en": ["Product Design", "User Research", "Data Analysis", "Product"],
            "is_active": True,
            "created_by": "A0001"
        },
        {
            "title": "UI/UX 设计师",
            "title_en": "UI/UX Designer",
            "department": "设计部",
            "department_en": "Design",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京/远程",
            "location_en": "Beijing/Remote",
            "experience": "2-4年",
            "experience_en": "2-4 years",
            "salary": "10-18K",
            "salary_en": "10-18K",
            "description": "负责产品界面设计和用户体验优化",
            "description_en": "Responsible for product interface design and user experience optimization",
            "requirements": [
                "熟练掌握设计工具",
                "有移动端设计经验",
                "了解设计规范和用户心理",
                "有平台类产品设计经验优先"
            ],
            "requirements_en": [
                "Proficient in design tools",
                "Mobile design experience",
                "Understanding of design standards and user psychology",
                "Platform product design experience preferred"
            ],
            "tags": ["UI设计", "UX设计", "Figma", "设计"],
            "tags_en": ["UI Design", "UX Design", "Figma", "Design"],
            "is_active": True,
            "created_by": "A0001"
        },
        {
            "title": "运营专员",
            "title_en": "Operations Specialist",
            "department": "运营部",
            "department_en": "Operations",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京",
            "location_en": "Beijing",
            "experience": "1-3年",
            "experience_en": "1-3 years",
            "salary": "8-15K",
            "salary_en": "8-15K",
            "description": "负责用户运营和内容运营，提升用户活跃度",
            "description_en": "Responsible for user operations and content operations, improving user activity",
            "requirements": [
                "有互联网运营经验",
                "熟悉社交媒体运营",
                "具备数据分析能力",
                "有社区运营经验优先"
            ],
            "requirements_en": [
                "Internet operations experience",
                "Familiar with social media operations",
                "Data analysis capabilities",
                "Community operations experience preferred"
            ],
            "tags": ["用户运营", "内容运营", "数据分析", "运营"],
            "tags_en": ["User Operations", "Content Operations", "Data Analysis", "Operations"],
            "is_active": True,
            "created_by": "A0001"
        },
        {
            "title": "客服专员",
            "title_en": "Customer Service Specialist",
            "department": "客服部",
            "department_en": "Customer Service",
            "type": "全职",
            "type_en": "Full-time",
            "location": "北京/远程",
            "location_en": "Beijing/Remote",
            "experience": "1-2年",
            "experience_en": "1-2 years",
            "salary": "6-10K",
            "salary_en": "6-10K",
            "description": "负责用户咨询和问题处理，维护用户关系",
            "description_en": "Responsible for user consultation and problem handling, maintaining user relationships",
            "requirements": [
                "具备良好的沟通能力",
                "有客服工作经验",
                "熟悉在线客服工具",
                "有耐心和责任心"
            ],
            "requirements_en": [
                "Good communication skills",
                "Customer service work experience",
                "Familiar with online customer service tools",
                "Patience and responsibility"
            ],
            "tags": ["客户服务", "沟通能力", "问题解决", "客服"],
            "tags_en": ["Customer Service", "Communication Skills", "Problem Solving", "Customer Service"],
            "is_active": True,
            "created_by": "A0001"
        }
    ]
    
    db = SessionLocal()
    try:
        # 检查是否已有数据
        existing_count = db.query(JobPosition).count()
        if existing_count > 0:
            print(f"数据库中已有 {existing_count} 个岗位，跳过初始化")
            return
        
        # 创建岗位
        for pos_data in positions_data:
            position = JobPosition(
                title=pos_data["title"],
                title_en=pos_data["title_en"],
                department=pos_data["department"],
                department_en=pos_data["department_en"],
                type=pos_data["type"],
                type_en=pos_data["type_en"],
                location=pos_data["location"],
                location_en=pos_data["location_en"],
                experience=pos_data["experience"],
                experience_en=pos_data["experience_en"],
                salary=pos_data["salary"],
                salary_en=pos_data["salary_en"],
                description=pos_data["description"],
                description_en=pos_data["description_en"],
                requirements=json.dumps(pos_data["requirements"], ensure_ascii=False),
                requirements_en=json.dumps(pos_data["requirements_en"], ensure_ascii=False),
                tags=json.dumps(pos_data["tags"], ensure_ascii=False),
                tags_en=json.dumps(pos_data["tags_en"], ensure_ascii=False),
                is_active=1 if pos_data["is_active"] else 0,
                created_by=pos_data["created_by"]
            )
            db.add(position)
        
        db.commit()
        print(f"成功初始化 {len(positions_data)} 个岗位到数据库")
        
    except Exception as e:
        print(f"初始化岗位数据失败: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_job_positions()
