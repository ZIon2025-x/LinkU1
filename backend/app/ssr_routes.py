"""
SSR (Server-Side Rendering) 路由
为社交媒体爬虫（微信、Facebook、Twitter 等）提供正确的 Open Graph meta 标签
"""

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import logging
import re
from typing import Optional

from app.database import get_db
from app.deps import get_async_db_dependency
from app import models

logger = logging.getLogger(__name__)

ssr_router = APIRouter(tags=["SSR"])

# 社交媒体爬虫和AI爬虫的 User-Agent 特征
CRAWLER_PATTERNS = [
    # 社交媒体爬虫
    r'MicroMessenger',      # 微信
    r'WeChat',              # 微信
    r'Weixin',              # 微信
    r'facebookexternalhit', # Facebook
    r'Facebot',             # Facebook
    r'Twitterbot',          # Twitter
    r'LinkedInBot',         # LinkedIn
    r'Slackbot',            # Slack
    r'TelegramBot',         # Telegram
    r'WhatsApp',            # WhatsApp
    r'Discordbot',          # Discord
    r'Pinterest',           # Pinterest
    # 搜索引擎爬虫
    r'Googlebot',           # Google
    r'bingbot',             # Bing
    r'Baiduspider',         # 百度
    r'YandexBot',           # Yandex
    r'DuckDuckBot',         # DuckDuckGo
    # AI 爬虫 - 让AI能够访问和推荐网站
    r'GPTBot',              # ChatGPT (OpenAI)
    r'anthropic-ai',        # Claude (Anthropic)
    r'Google-Extended',     # Google Bard / Gemini
    r'PerplexityBot',       # Perplexity AI
    r'CCBot',               # Common Crawl (被很多AI使用)
    r'Applebot-Extended',   # Apple AI
    r'FacebookBot',         # Meta AI
    r'Bytespider',          # 字节跳动AI
    r'Diffbot',             # Diffbot (AI数据提取)
    r'BingPreview',         # Bing AI预览
]

def is_crawler(user_agent: str) -> bool:
    """检测是否是社交媒体爬虫"""
    if not user_agent:
        return False
    for pattern in CRAWLER_PATTERNS:
        if re.search(pattern, user_agent, re.IGNORECASE):
            return True
    return False


def generate_html(
    title: str,
    description: str,
    image_url: str,
    page_url: str,
    site_name: str = "Link²Ur"
) -> str:
    """生成包含 Open Graph meta 标签的 HTML"""
    
    # 确保图片 URL 是完整的
    if image_url and not image_url.startswith('http'):
        if image_url.startswith('//'):
            image_url = 'https:' + image_url
        elif image_url.startswith('/'):
            image_url = 'https://www.link2ur.com' + image_url
        else:
            image_url = 'https://www.link2ur.com/' + image_url
    
    # 默认图片
    if not image_url:
        image_url = 'https://www.link2ur.com/static/favicon.png'
    
    # 截断描述
    if description and len(description) > 200:
        description = description[:200] + '...'
    
    # 清理 HTML 标签
    if description:
        description = re.sub(r'<[^>]+>', '', description)
    
    html = f'''<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{title}</title>
    
    <!-- 基本 Meta -->
    <meta name="description" content="{description}">
    
    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="{page_url}">
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{description}">
    <meta property="og:image" content="{image_url}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:site_name" content="{site_name}">
    
    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:url" content="{page_url}">
    <meta name="twitter:title" content="{title}">
    <meta name="twitter:description" content="{description}">
    <meta name="twitter:image" content="{image_url}">
    
    <!-- 微信分享 -->
    <meta name="weixin:title" content="{title}">
    <meta name="weixin:description" content="{description}">
    <meta name="weixin:image" content="{image_url}">
    
    <!-- 重定向到实际页面（对于普通浏览器） -->
    <meta http-equiv="refresh" content="0; url={page_url}">
    
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: #f5f5f5;
        }}
        .loading {{
            text-align: center;
            color: #666;
        }}
    </style>
</head>
<body>
    <div class="loading">
        <p>正在跳转到 {site_name}...</p>
        <p><a href="{page_url}">点击这里</a>如果没有自动跳转</p>
    </div>
</body>
</html>'''
    return html


# ==================== 任务详情页 SSR ====================

@ssr_router.get("/zh/tasks/{task_id}")
@ssr_router.get("/en/tasks/{task_id}")
@ssr_router.get("/tasks/{task_id}")
async def ssr_task_detail(
    request: Request,
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    任务详情页 SSR
    - 如果是爬虫，返回包含正确 meta 标签的 HTML
    - 如果是普通用户，重定向到前端 SPA
    """
    user_agent = request.headers.get("User-Agent", "")
    
    # 如果不是爬虫，重定向到前端
    if not is_crawler(user_agent):
        # 提取语言前缀
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/tasks/{task_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 获取任务信息
    try:
        result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = result.scalar_one_or_none()
        
        if not task:
            # 任务不存在，返回默认 meta
            return HTMLResponse(
                content=generate_html(
                    title="任务不存在 - Link²Ur",
                    description="该任务可能已被删除或不存在",
                    image_url="",
                    page_url=f"https://www.link2ur.com/zh/tasks/{task_id}"
                ),
                status_code=404
            )
        
        # 构建分享信息
        title = f"{task.title} - Link²Ur任务平台"
        description = task.description or "在 Link²Ur 查看任务详情"
        
        # 获取任务图片
        image_url = ""
        if task.images and len(task.images) > 0:
            image_url = task.images[0]
        
        page_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        
        logger.info(f"SSR 任务详情: task_id={task_id}, title={task.title}, image={image_url}")
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=description,
                image_url=image_url,
                page_url=page_url
            )
        )
        
    except Exception as e:
        logger.error(f"SSR 任务详情失败: {e}")
        return HTMLResponse(
            content=generate_html(
                title="Link²Ur - 任务平台",
                description="专业的任务发布与技能匹配平台",
                image_url="",
                page_url=f"https://www.link2ur.com/zh/tasks/{task_id}"
            )
        )


# ==================== 排行榜详情页 SSR ====================

@ssr_router.get("/zh/leaderboard/custom/{leaderboard_id}")
@ssr_router.get("/en/leaderboard/custom/{leaderboard_id}")
@ssr_router.get("/leaderboard/custom/{leaderboard_id}")
async def ssr_leaderboard_detail(
    request: Request,
    leaderboard_id: int,
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    排行榜详情页 SSR
    - 如果是爬虫，返回包含正确 meta 标签的 HTML
    - 如果是普通用户，重定向到前端 SPA
    """
    user_agent = request.headers.get("User-Agent", "")
    
    # 如果不是爬虫，重定向到前端
    if not is_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/leaderboard/custom/{leaderboard_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 获取排行榜信息
    try:
        result = await db.execute(
            select(models.CustomLeaderboard).where(models.CustomLeaderboard.id == leaderboard_id)
        )
        leaderboard = result.scalar_one_or_none()
        
        if not leaderboard:
            return HTMLResponse(
                content=generate_html(
                    title="排行榜不存在 - Link²Ur",
                    description="该排行榜可能已被删除或不存在",
                    image_url="",
                    page_url=f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
                ),
                status_code=404
            )
        
        # 构建分享信息
        title = f"{leaderboard.name} - Link²Ur榜单"
        description = leaderboard.description or f"来 Link²Ur 看看这个排行榜，共有 {leaderboard.item_count} 个竞品"
        image_url = leaderboard.cover_image or ""
        page_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        
        logger.info(f"SSR 排行榜详情: id={leaderboard_id}, name={leaderboard.name}, image={image_url}")
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=description,
                image_url=image_url,
                page_url=page_url
            )
        )
        
    except Exception as e:
        logger.error(f"SSR 排行榜详情失败: {e}")
        return HTMLResponse(
            content=generate_html(
                title="Link²Ur - 榜单平台",
                description="发现和创建有趣的排行榜",
                image_url="",
                page_url=f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
            )
        )


# ==================== 论坛帖子详情页 SSR ====================

@ssr_router.get("/zh/forum/post/{post_id}")
@ssr_router.get("/en/forum/post/{post_id}")
@ssr_router.get("/forum/post/{post_id}")
async def ssr_forum_post_detail(
    request: Request,
    post_id: int,
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    论坛帖子详情页 SSR
    """
    user_agent = request.headers.get("User-Agent", "")
    
    if not is_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/forum/post/{post_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    try:
        result = await db.execute(
            select(models.ForumPost).where(models.ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()
        
        if not post:
            return HTMLResponse(
                content=generate_html(
                    title="帖子不存在 - Link²Ur",
                    description="该帖子可能已被删除或不存在",
                    image_url="",
                    page_url=f"https://www.link2ur.com/zh/forum/post/{post_id}"
                ),
                status_code=404
            )
        
        title = f"{post.title} - Link²Ur论坛"
        # 清理 HTML 内容
        description = re.sub(r'<[^>]+>', '', post.content or "")
        
        # 尝试从内容中提取第一张图片
        image_url = ""
        img_match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', post.content or "")
        if img_match:
            image_url = img_match.group(1)
        
        page_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=description,
                image_url=image_url,
                page_url=page_url
            )
        )
        
    except Exception as e:
        logger.error(f"SSR 论坛帖子详情失败: {e}")
        return HTMLResponse(
            content=generate_html(
                title="Link²Ur - 论坛",
                description="加入 Link²Ur 论坛，分享你的想法",
                image_url="",
                page_url=f"https://www.link2ur.com/zh/forum/post/{post_id}"
            )
        )

