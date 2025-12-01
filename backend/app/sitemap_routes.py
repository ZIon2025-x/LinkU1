"""
动态Sitemap生成路由
用于SEO优化，让搜索引擎能够索引所有任务
"""

import logging
from datetime import datetime
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from app.deps import get_db
from app.models import Task, FleaMarketItem, ForumPost, CustomLeaderboard
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# 创建sitemap路由器
sitemap_router = APIRouter()


@sitemap_router.get("/sitemap.xml")
def generate_sitemap(db: Session = Depends(get_db)):
    """生成动态sitemap.xml，包含所有开放的任务"""
    try:
        # 获取当前UTC时间
        now_utc = get_utc_time()
        
        # 获取所有开放的任务（只依赖状态，不依赖 deadline）
        # 注意：deadline 判断由业务逻辑处理，这里只关注状态
        # 如果任务状态是 open 但 deadline 已过期，业务层应该负责关闭，而不是在 sitemap 层过滤
        tasks = db.query(Task).filter(
            Task.status == "open"
        ).order_by(Task.created_at.desc()).all()
        
        # 构建sitemap XML
        sitemap_lines = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        ]
        
        # 添加主要页面
        base_url = "https://www.link2ur.com"
        today = get_utc_time().strftime("%Y-%m-%d")
        
        main_pages = [
            ("/", "1.0", "daily"),
            ("/en", "0.9", "daily"),
            ("/zh", "0.9", "daily"),
            ("/en/tasks", "0.8", "daily"),
            ("/zh/tasks", "0.8", "daily"),
            ("/en/flea-market", "0.8", "daily"),  # 新增
            ("/zh/flea-market", "0.8", "daily"),  # 新增
            ("/en/forum", "0.8", "daily"),        # 新增
            ("/zh/forum", "0.8", "daily"),        # 新增
            ("/en/forum/leaderboard", "0.8", "daily"),  # 榜单列表页
            ("/zh/forum/leaderboard", "0.8", "daily"),  # 榜单列表页
        ]
        
        for path, priority, changefreq in main_pages:
            sitemap_lines.append(f'  <url>')
            sitemap_lines.append(f'    <loc>{base_url}{path}</loc>')
            sitemap_lines.append(f'    <lastmod>{today}</lastmod>')
            sitemap_lines.append(f'    <changefreq>{changefreq}</changefreq>')
            sitemap_lines.append(f'    <priority>{priority}</priority>')
            sitemap_lines.append(f'  </url>')
        
        # 添加所有任务详情页
        for task in tasks:
            task_lastmod = task.updated_at.strftime("%Y-%m-%d") if task.updated_at else task.created_at.strftime("%Y-%m-%d")
            
            for lang in ["en", "zh"]:
                sitemap_lines.append(f'  <url>')
                sitemap_lines.append(f'    <loc>{base_url}/{lang}/tasks/{task.id}</loc>')
                sitemap_lines.append(f'    <lastmod>{task_lastmod}</lastmod>')
                sitemap_lines.append(f'    <changefreq>weekly</changefreq>')
                sitemap_lines.append(f'    <priority>0.7</priority>')
                sitemap_lines.append(f'  </url>')
        
        # 添加跳蚤市场商品（计划中）
        try:
            items = db.query(FleaMarketItem).filter(
                FleaMarketItem.status == 'active'
            ).all()
            
            for item in items:
                item_lastmod = item.updated_at.strftime("%Y-%m-%d") if item.updated_at else item.created_at.strftime("%Y-%m-%d")
                
                for lang in ["en", "zh"]:
                    sitemap_lines.append(f'  <url>')
                    sitemap_lines.append(f'    <loc>{base_url}/{lang}/flea-market/{item.id}</loc>')
                    sitemap_lines.append(f'    <lastmod>{item_lastmod}</lastmod>')
                    sitemap_lines.append(f'    <changefreq>weekly</changefreq>')
                    sitemap_lines.append(f'    <priority>0.6</priority>')
                    sitemap_lines.append(f'  </url>')
        except Exception as e:
            logger.warning(f"添加跳蚤市场商品到sitemap失败: {e}")
        
        # 添加论坛帖子（计划中）
        try:
            posts = db.query(ForumPost).filter(
                and_(
                    ForumPost.is_deleted == False,  # 使用 == False 而不是 is_(False)，因为这是 SQLAlchemy 的布尔比较
                    ForumPost.is_visible == True
                )
            ).all()
            
            for post in posts:
                post_lastmod = post.updated_at.strftime("%Y-%m-%d") if post.updated_at else post.created_at.strftime("%Y-%m-%d")
                
                for lang in ["en", "zh"]:
                    sitemap_lines.append(f'  <url>')
                    sitemap_lines.append(f'    <loc>{base_url}/{lang}/forum/post/{post.id}</loc>')
                    sitemap_lines.append(f'    <lastmod>{post_lastmod}</lastmod>')
                    sitemap_lines.append(f'    <changefreq>weekly</changefreq>')
                    sitemap_lines.append(f'    <priority>0.6</priority>')
                    sitemap_lines.append(f'  </url>')
        except Exception as e:
            logger.warning(f"添加论坛帖子到sitemap失败: {e}")
        
        # 添加自定义榜单详情页
        try:
            leaderboards = db.query(CustomLeaderboard).filter(
                CustomLeaderboard.status == "active"
            ).all()
            
            for leaderboard in leaderboards:
                leaderboard_lastmod = leaderboard.updated_at.strftime("%Y-%m-%d") if leaderboard.updated_at else leaderboard.created_at.strftime("%Y-%m-%d")
                
                for lang in ["en", "zh"]:
                    sitemap_lines.append(f'  <url>')
                    sitemap_lines.append(f'    <loc>{base_url}/{lang}/leaderboard/custom/{leaderboard.id}</loc>')
                    sitemap_lines.append(f'    <lastmod>{leaderboard_lastmod}</lastmod>')
                    sitemap_lines.append(f'    <changefreq>weekly</changefreq>')
                    sitemap_lines.append(f'    <priority>0.7</priority>')
                    sitemap_lines.append(f'  </url>')
        except Exception as e:
            logger.warning(f"添加自定义榜单到sitemap失败: {e}")
        
        sitemap_lines.append('</urlset>')
        sitemap_xml = '\n'.join(sitemap_lines)
        
        return Response(
            content=sitemap_xml,
            media_type="application/xml",
            headers={
                "Cache-Control": "public, max-age=43200"  # 缓存12小时（任务数量多时生成较慢，建议延长缓存）
                # 如果任务数量 > 10,000，建议改为 86400（24小时）或加一层 Redis 缓存
            }
        )
    except Exception as e:
        logger.error(f"生成sitemap失败: {e}", exc_info=True)
        # 返回基础sitemap，至少包含主要页面
        fallback_sitemap = f'''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://www.link2ur.com/</loc>
    <lastmod>{get_utc_time().strftime("%Y-%m-%d")}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://www.link2ur.com/en/tasks</loc>
    <lastmod>{get_utc_time().strftime("%Y-%m-%d")}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>'''
        return Response(
            content=fallback_sitemap,
            media_type="application/xml"
        )

