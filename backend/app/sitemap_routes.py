"""
动态Sitemap生成路由
用于SEO优化，让搜索引擎能够索引所有任务
"""

import logging
from datetime import datetime
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.deps import get_db
from app.models import Task
from app.time_utils_v2 import TimeHandlerV2

logger = logging.getLogger(__name__)

# 创建sitemap路由器
sitemap_router = APIRouter()


@sitemap_router.get("/sitemap.xml")
def generate_sitemap(db: Session = Depends(get_db)):
    """生成动态sitemap.xml，包含所有开放的任务"""
    try:
        # 获取当前UTC时间
        now_utc = TimeHandlerV2.get_utc_now()
        
        # 获取所有开放且未过期的任务（包括灵活模式任务，deadline 为 NULL）
        tasks = db.query(Task).filter(
            Task.status == "open",
            or_(
                Task.deadline > now_utc,  # 有截止日期且未过期
                Task.deadline.is_(None)  # 灵活模式（无截止日期）
            )
        ).order_by(Task.created_at.desc()).all()
        
        # 构建sitemap XML
        sitemap_lines = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        ]
        
        # 添加主要页面
        base_url = "https://www.link2ur.com"
        today = datetime.now().strftime("%Y-%m-%d")
        
        main_pages = [
            ("/", "1.0", "daily"),
            ("/en", "0.9", "daily"),
            ("/zh", "0.9", "daily"),
            ("/en/tasks", "0.8", "daily"),
            ("/zh/tasks", "0.8", "daily"),
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
            # 任务详情页URL格式：/en/tasks/{task_id} 或 /zh/tasks/{task_id}
            # 为了SEO，我们同时添加英文和中文版本
            task_lastmod = task.updated_at.strftime("%Y-%m-%d") if task.updated_at else task.created_at.strftime("%Y-%m-%d")
            
            for lang in ["en", "zh"]:
                sitemap_lines.append(f'  <url>')
                sitemap_lines.append(f'    <loc>{base_url}/{lang}/tasks/{task.id}</loc>')
                sitemap_lines.append(f'    <lastmod>{task_lastmod}</lastmod>')
                sitemap_lines.append(f'    <changefreq>weekly</changefreq>')
                sitemap_lines.append(f'    <priority>0.7</priority>')
                sitemap_lines.append(f'  </url>')
        
        sitemap_lines.append('</urlset>')
        sitemap_xml = '\n'.join(sitemap_lines)
        
        return Response(
            content=sitemap_xml,
            media_type="application/xml",
            headers={
                "Cache-Control": "public, max-age=3600"  # 缓存1小时
            }
        )
    except Exception as e:
        logger.error(f"生成sitemap失败: {e}")
        # 返回基础sitemap，至少包含主要页面
        fallback_sitemap = f'''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://www.link2ur.com/</loc>
    <lastmod>{datetime.now().strftime("%Y-%m-%d")}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://www.link2ur.com/en/tasks</loc>
    <lastmod>{datetime.now().strftime("%Y-%m-%d")}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>'''
        return Response(
            content=fallback_sitemap,
            media_type="application/xml"
        )

