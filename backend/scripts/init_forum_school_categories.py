"""
初始化论坛学校板块脚本
自动为英国大学填充编码并创建对应的论坛板块

使用方法:
    python backend/scripts/init_forum_school_categories.py

功能:
    1. 为所有英国大学（country='UK'）自动生成并填充 code 字段
    2. 为每个英国大学自动创建对应的论坛板块（如果不存在）
    3. 确保大学编码和板块编码的一致性
"""

import sys
import os
import logging
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app import models

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# 大学编码映射表（根据 email_domain 生成编码）
UNIVERSITY_CODE_MAP = {
    'bristol.ac.uk': 'UOB',
    'ox.ac.uk': 'UOX',
    'cam.ac.uk': 'UCAM',
    'imperial.ac.uk': 'ICL',
    'lse.ac.uk': 'LSE',
    'ucl.ac.uk': 'UCL',
    'kcl.ac.uk': 'KCL',
    'manchester.ac.uk': 'UOM',
    'ed.ac.uk': 'UOE',
    'bham.ac.uk': 'UOBH',
    'leeds.ac.uk': 'UOL',
    'liverpool.ac.uk': 'UOLP',
    'sheffield.ac.uk': 'UOS',
    'nottingham.ac.uk': 'UON',
    'soton.ac.uk': 'UOSO',
    'warwick.ac.uk': 'UOW',
    'york.ac.uk': 'UOY',
    'durham.ac.uk': 'UDU',
    'essex.ac.uk': 'UOE',
    'student.gla.ac.uk': 'UOG',  # Glasgow
    'gla.ac.uk': 'UOG',  # Glasgow 备用
}


def generate_university_code(email_domain: str, name: str) -> str:
    """
    根据 email_domain 或 name 生成大学编码
    
    规则:
    1. 优先使用预定义的映射表
    2. 如果没有映射，从 email_domain 提取主要部分并转换为大写
    3. 如果 email_domain 是 student.xxx.ac.uk 格式，提取 xxx 部分
    """
    email_domain_lower = email_domain.lower()
    
    # 1. 检查预定义映射
    if email_domain_lower in UNIVERSITY_CODE_MAP:
        return UNIVERSITY_CODE_MAP[email_domain_lower]
    
    # 2. 处理 student.xxx.ac.uk 格式
    if email_domain_lower.startswith('student.'):
        domain_part = email_domain_lower.replace('student.', '').replace('.ac.uk', '')
    else:
        domain_part = email_domain_lower.replace('.ac.uk', '')
    
    # 3. 提取主要部分（去掉子域名）
    parts = domain_part.split('.')
    main_part = parts[-1] if parts else domain_part
    
    # 4. 转换为编码（取前3-4个大写字母）
    code = main_part.upper()[:4]
    
    # 5. 如果编码太短，从名称中提取
    if len(code) < 3:
        # 从大学名称中提取首字母
        name_words = name.upper().split()
        if len(name_words) >= 2:
            code = ''.join([w[0] for w in name_words[:3]])[:4]
        else:
            code = name_words[0][:4] if name_words else 'UNK'
    
    return code


def init_university_codes(db: Session):
    """为所有英国大学填充 code 字段"""
    logger.info("开始初始化大学编码...")
    
    # 查询所有英国大学（country='UK' 或 email_domain 以 .ac.uk 结尾）
    universities = db.query(models.University).filter(
        models.University.country == 'UK'
    ).all()
    
    # 如果没有 country='UK' 的记录，通过 email_domain 判断
    if not universities:
        universities = db.query(models.University).filter(
            models.University.email_domain.like('%.ac.uk')
        ).all()
        logger.info(f"通过 email_domain 找到 {len(universities)} 个英国大学")
    
    updated_count = 0
    skipped_count = 0
    
    for uni in universities:
        # 如果已有编码，跳过
        if uni.code:
            logger.debug(f"大学 {uni.name} ({uni.email_domain}) 已有编码: {uni.code}")
            skipped_count += 1
            continue
        
        # 生成编码
        code = generate_university_code(uni.email_domain, uni.name)
        
        # 检查编码是否已存在（唯一性约束）
        existing = db.query(models.University).filter(
            models.University.code == code,
            models.University.id != uni.id
        ).first()
        
        if existing:
            # 如果编码冲突，添加后缀
            counter = 1
            original_code = code
            while existing:
                code = f"{original_code}{counter}"
                existing = db.query(models.University).filter(
                    models.University.code == code,
                    models.University.id != uni.id
                ).first()
                counter += 1
            logger.warning(f"编码冲突，使用新编码: {uni.name} -> {code} (原: {original_code})")
        
        # 更新编码
        uni.code = code
        if not uni.country:
            uni.country = 'UK'
        
        updated_count += 1
        logger.info(f"✓ {uni.name} ({uni.email_domain}) -> {code}")
    
    db.commit()
    logger.info(f"✅ 大学编码初始化完成: 更新 {updated_count} 个，跳过 {skipped_count} 个")


def init_forum_categories(db: Session):
    """为每个英国大学创建对应的论坛板块"""
    logger.info("开始初始化论坛学校板块...")
    
    # 查询所有有编码的英国大学
    universities = db.query(models.University).filter(
        models.University.country == 'UK',
        models.University.code.isnot(None),
        models.University.is_active == True
    ).all()
    
    if not universities:
        logger.warning("未找到有编码的英国大学，请先运行 init_university_codes")
        return
    
    created_count = 0
    skipped_count = 0
    
    for uni in universities:
        # 检查板块是否已存在
        existing_category = db.query(models.ForumCategory).filter(
            models.ForumCategory.university_code == uni.code,
            models.ForumCategory.type == 'university'
        ).first()
        
        if existing_category:
            logger.debug(f"板块已存在: {uni.name} ({uni.code})")
            skipped_count += 1
            continue
        
        # 创建新板块
        category_name = uni.name_cn or uni.name
        category_description = f"{category_name}学生交流讨论区"
        
        # 确定排序顺序（可以根据需要调整）
        sort_order = uni.id  # 使用大学ID作为排序
        
        category = models.ForumCategory(
            name=category_name,
            description=category_description,
            type='university',
            country='UK',
            university_code=uni.code,
            sort_order=sort_order,
            is_visible=True,
            is_admin_only=False
        )
        
        db.add(category)
        created_count += 1
        logger.info(f"✓ 创建板块: {category_name} ({uni.code})")
    
    db.commit()
    logger.info(f"✅ 论坛板块初始化完成: 创建 {created_count} 个，跳过 {skipped_count} 个")


def verify_consistency(db: Session):
    """验证大学编码和板块编码的一致性"""
    logger.info("开始验证数据一致性...")
    
    # 查询所有大学板块
    categories = db.query(models.ForumCategory).filter(
        models.ForumCategory.type == 'university'
    ).all()
    
    errors = []
    warnings = []
    
    for category in categories:
        if not category.university_code:
            errors.append(f"板块 {category.name} (ID: {category.id}) 缺少 university_code")
            continue
        
        # 查找对应的大学
        university = db.query(models.University).filter(
            models.University.code == category.university_code
        ).first()
        
        if not university:
            errors.append(f"板块 {category.name} 的 university_code '{category.university_code}' 找不到对应的大学")
        elif university.country != 'UK':
            warnings.append(f"板块 {category.name} 对应的大学 {university.name} 不是英国大学 (country: {university.country})")
    
    # 查询所有有编码的英国大学，检查是否有对应板块
    universities = db.query(models.University).filter(
        models.University.country == 'UK',
        models.University.code.isnot(None),
        models.University.is_active == True
    ).all()
    
    for uni in universities:
        category = db.query(models.ForumCategory).filter(
            models.ForumCategory.university_code == uni.code,
            models.ForumCategory.type == 'university'
        ).first()
        
        if not category:
            warnings.append(f"大学 {uni.name} ({uni.code}) 没有对应的论坛板块")
    
    if errors:
        logger.error("❌ 发现错误:")
        for error in errors:
            logger.error(f"  - {error}")
    
    if warnings:
        logger.warning("⚠️  发现警告:")
        for warning in warnings:
            logger.warning(f"  - {warning}")
    
    if not errors and not warnings:
        logger.info("✅ 数据一致性验证通过")
    
    return len(errors) == 0


def main():
    """主函数"""
    logger.info("=" * 60)
    logger.info("论坛学校板块初始化脚本")
    logger.info("=" * 60)
    
    db = SessionLocal()
    
    try:
        # 1. 初始化大学编码
        init_university_codes(db)
        
        # 2. 初始化论坛板块
        init_forum_categories(db)
        
        # 3. 验证一致性
        is_consistent = verify_consistency(db)
        
        if is_consistent:
            logger.info("=" * 60)
            logger.info("✅ 初始化完成！")
            logger.info("=" * 60)
        else:
            logger.error("=" * 60)
            logger.error("❌ 初始化完成，但发现数据不一致问题，请检查上述错误")
            logger.error("=" * 60)
            sys.exit(1)
    
    except Exception as e:
        logger.error(f"❌ 初始化失败: {e}", exc_info=True)
        db.rollback()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()

