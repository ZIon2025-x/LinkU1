"""
迁移旧数据的双语字段
为所有没有双语字段的论坛板块和排行榜自动翻译并填充双语字段
"""
import asyncio
import sys
import os
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.models import ForumCategory, CustomLeaderboard
from app.utils.bilingual_helper import auto_fill_bilingual_fields
from app.database import ASYNC_DATABASE_URL

import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def migrate_forum_categories(db: AsyncSession):
    """迁移论坛板块的双语字段"""
    logger.info("开始迁移论坛板块的双语字段...")
    
    # 查询所有没有双语字段的板块
    result = await db.execute(
        select(ForumCategory).where(
            (ForumCategory.name_en.is_(None)) | 
            (ForumCategory.name_zh.is_(None)) |
            (ForumCategory.description_en.is_(None)) |
            (ForumCategory.description_zh.is_(None))
        )
    )
    categories = result.scalars().all()
    
    total = len(categories)
    logger.info(f"找到 {total} 个需要更新的板块")
    
    updated_count = 0
    error_count = 0
    
    for idx, category in enumerate(categories, 1):
        try:
            logger.info(f"处理板块 {idx}/{total}: {category.name} (ID: {category.id})")
            
            # 检查哪些字段需要填充
            needs_name_en = not category.name_en
            needs_name_zh = not category.name_zh
            needs_description_en = category.description and not category.description_en
            needs_description_zh = category.description and not category.description_zh
            
            if not (needs_name_en or needs_name_zh or needs_description_en or needs_description_zh):
                logger.info(f"  板块 {category.id} 已有双语字段，跳过")
                continue
            
            # 自动填充双语字段
            _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
                name=category.name,
                description=category.description,
                name_en=category.name_en,
                name_zh=category.name_zh,
                description_en=category.description_en,
                description_zh=category.description_zh,
            )
            
            # 更新字段（只更新缺失的字段）
            if needs_name_en and name_en:
                category.name_en = name_en
            if needs_name_zh and name_zh:
                category.name_zh = name_zh
            if needs_description_en and description_en:
                category.description_en = description_en
            if needs_description_zh and description_zh:
                category.description_zh = description_zh
            
            await db.flush()
            updated_count += 1
            
            logger.info(f"  ✓ 板块 {category.id} 双语字段已更新")
            
            # 每10个提交一次，避免事务过大
            if updated_count % 10 == 0:
                await db.commit()
                logger.info(f"  已提交 {updated_count} 个板块的更新")
        
        except Exception as e:
            error_count += 1
            logger.error(f"  ✗ 更新板块 {category.id} 失败: {e}")
            await db.rollback()
            continue
    
    # 最终提交
    try:
        await db.commit()
        logger.info(f"论坛板块迁移完成: 成功 {updated_count} 个, 失败 {error_count} 个")
    except Exception as e:
        logger.error(f"提交论坛板块更新失败: {e}")
        await db.rollback()
    
    return updated_count, error_count


async def migrate_leaderboards(db: AsyncSession):
    """迁移排行榜的双语字段"""
    logger.info("开始迁移排行榜的双语字段...")
    
    # 查询所有没有双语字段的排行榜
    result = await db.execute(
        select(CustomLeaderboard).where(
            (CustomLeaderboard.name_en.is_(None)) | 
            (CustomLeaderboard.name_zh.is_(None)) |
            (CustomLeaderboard.description_en.is_(None)) |
            (CustomLeaderboard.description_zh.is_(None))
        )
    )
    leaderboards = result.scalars().all()
    
    total = len(leaderboards)
    logger.info(f"找到 {total} 个需要更新的排行榜")
    
    updated_count = 0
    error_count = 0
    
    for idx, leaderboard in enumerate(leaderboards, 1):
        try:
            logger.info(f"处理排行榜 {idx}/{total}: {leaderboard.name} (ID: {leaderboard.id})")
            
            # 检查哪些字段需要填充
            needs_name_en = not leaderboard.name_en
            needs_name_zh = not leaderboard.name_zh
            needs_description_en = leaderboard.description and not leaderboard.description_en
            needs_description_zh = leaderboard.description and not leaderboard.description_zh
            
            if not (needs_name_en or needs_name_zh or needs_description_en or needs_description_zh):
                logger.info(f"  排行榜 {leaderboard.id} 已有双语字段，跳过")
                continue
            
            # 自动填充双语字段
            _, name_en, name_zh, description_en, description_zh = await auto_fill_bilingual_fields(
                name=leaderboard.name,
                description=leaderboard.description,
                name_en=leaderboard.name_en,
                name_zh=leaderboard.name_zh,
                description_en=leaderboard.description_en,
                description_zh=leaderboard.description_zh,
            )
            
            # 更新字段（只更新缺失的字段）
            if needs_name_en and name_en:
                leaderboard.name_en = name_en
            if needs_name_zh and name_zh:
                leaderboard.name_zh = name_zh
            if needs_description_en and description_en:
                leaderboard.description_en = description_en
            if needs_description_zh and description_zh:
                leaderboard.description_zh = description_zh
            
            await db.flush()
            updated_count += 1
            
            logger.info(f"  ✓ 排行榜 {leaderboard.id} 双语字段已更新")
            
            # 每10个提交一次，避免事务过大
            if updated_count % 10 == 0:
                await db.commit()
                logger.info(f"  已提交 {updated_count} 个排行榜的更新")
        
        except Exception as e:
            error_count += 1
            logger.error(f"  ✗ 更新排行榜 {leaderboard.id} 失败: {e}")
            await db.rollback()
            continue
    
    # 最终提交
    try:
        await db.commit()
        logger.info(f"排行榜迁移完成: 成功 {updated_count} 个, 失败 {error_count} 个")
    except Exception as e:
        logger.error(f"提交排行榜更新失败: {e}")
        await db.rollback()
    
    return updated_count, error_count


async def main():
    """主函数"""
    logger.info("=" * 60)
    logger.info("开始迁移旧数据的双语字段")
    logger.info("=" * 60)
    
    # 获取数据库URL
    database_url = ASYNC_DATABASE_URL
    if not database_url:
        logger.error("无法获取数据库URL，请检查环境变量 ASYNC_DATABASE_URL")
        return
    
    logger.info(f"使用数据库URL: {database_url.split('@')[1] if '@' in database_url else '***'}")
    
    # 创建异步引擎
    engine = create_async_engine(database_url, echo=False)
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    try:
        async with async_session() as db:
            # 迁移论坛板块
            category_updated, category_errors = await migrate_forum_categories(db)
            
            # 迁移排行榜
            leaderboard_updated, leaderboard_errors = await migrate_leaderboards(db)
            
            logger.info("=" * 60)
            logger.info("迁移完成统计:")
            logger.info(f"  论坛板块: 成功 {category_updated} 个, 失败 {category_errors} 个")
            logger.info(f"  排行榜: 成功 {leaderboard_updated} 个, 失败 {leaderboard_errors} 个")
            logger.info("=" * 60)
    
    except Exception as e:
        logger.error(f"迁移过程中发生错误: {e}", exc_info=True)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
