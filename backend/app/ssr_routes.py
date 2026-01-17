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

# 不执行JavaScript的爬虫（需要SSR）
# 这些爬虫通常只读取HTML，不执行JavaScript
NON_JS_CRAWLERS = [
    r'MicroMessenger',      # 微信（不执行JS）
    r'WeChat',              # 微信
    r'Weixin',              # 微信
    r'facebookexternalhit', # Facebook（不执行JS）
    r'Facebot',             # Facebook
    r'Twitterbot',          # Twitter（不执行JS）
    r'LinkedInBot',         # LinkedIn（不执行JS）
    r'Slackbot',            # Slack（不执行JS）
    r'TelegramBot',         # Telegram（不执行JS）
    r'WhatsApp',            # WhatsApp（不执行JS）
    r'Discordbot',          # Discord（不执行JS）
    r'Pinterest',           # Pinterest（不执行JS）
    r'Baiduspider',         # 百度（部分不执行JS）
    r'YandexBot',           # Yandex（部分不执行JS）
    r'CCBot',               # Common Crawl（不执行JS）
]

# iOS/macOS 链接预览请求的 User-Agent 模式
# 当用户在 iOS 分享面板中选择微信等应用时，系统会尝试获取链接预览
# 这些请求不执行 JavaScript，需要返回 SSR HTML
IOS_LINK_PREVIEW_PATTERNS = [
    r'CFNetwork',           # iOS/macOS 网络框架
    r'Darwin',              # macOS/iOS 内核标识
    r'LinkPresentation',     # iOS 链接预览框架
    r'com\.apple\.',         # Apple 应用标识
]

def is_ios_link_preview(user_agent: str) -> bool:
    """
    检测是否是 iOS/macOS 的链接预览请求
    这些请求来自 LPMetadataProvider，需要返回 SSR HTML
    """
    if not user_agent:
        return False
    
    # 策略1：检查是否包含 iOS 链接预览的特征模式
    for pattern in IOS_LINK_PREVIEW_PATTERNS:
        if re.search(pattern, user_agent, re.IGNORECASE):
            # 确保不是 Safari 浏览器（Safari 会执行 JS，不需要 SSR）
            if 'Safari' not in user_agent:
                logger.debug(f"检测到 iOS 链接预览请求（模式匹配）: User-Agent={user_agent[:150]}")
                return True
    
    # 策略2：如果 User-Agent 很短且不包含常见浏览器标识，可能是链接预览
    # iOS 链接预览的 User-Agent 通常比较短，且不包含浏览器标识
    common_browsers = ['Safari', 'Chrome', 'Firefox', 'Edge', 'Opera', 'Mozilla']
    if len(user_agent) < 100 and not any(browser in user_agent for browser in common_browsers):
        # 但排除明显的爬虫（它们已经在 NON_JS_CRAWLERS 中处理）
        if not any(re.search(pattern, user_agent, re.IGNORECASE) for pattern in NON_JS_CRAWLERS):
            logger.debug(f"检测到可能的 iOS 链接预览请求（短 User-Agent）: User-Agent={user_agent[:150]}")
            return True
    
    return False

# 执行JavaScript的现代爬虫（让它们直接执行JS，不需要SSR）
# 这些爬虫可以执行JavaScript，直接访问前端SPA即可
JS_CAPABLE_CRAWLERS = [
    r'Googlebot',           # Google（执行JS）
    r'bingbot',             # Bing（执行JS）
    r'GPTBot',              # ChatGPT (OpenAI) - 执行JS
    r'anthropic-ai',        # Claude (Anthropic) - 执行JS
    r'Google-Extended',     # Google Bard / Gemini - 执行JS
    r'PerplexityBot',       # Perplexity AI - 执行JS
    r'Applebot-Extended',   # Apple AI - 执行JS
    r'FacebookBot',         # Meta AI - 执行JS
    r'Bytespider',          # 字节跳动AI - 执行JS
    r'Diffbot',             # Diffbot - 执行JS
    r'BingPreview',         # Bing AI预览 - 执行JS
    r'DuckDuckBot',         # DuckDuckGo - 执行JS
]

def is_non_js_crawler(user_agent: str) -> bool:
    """
    检测是否是不执行JavaScript的爬虫（需要SSR）
    这些爬虫只读取HTML，不执行JavaScript，所以需要服务端渲染
    也包括 iOS/macOS 的链接预览请求
    """
    if not user_agent:
        return False
    for pattern in NON_JS_CRAWLERS:
        if re.search(pattern, user_agent, re.IGNORECASE):
            return True
    # 也检测 iOS 链接预览请求
    if is_ios_link_preview(user_agent):
        return True
    return False

def is_js_capable_crawler(user_agent: str) -> bool:
    """
    检测是否是能执行JavaScript的现代爬虫
    这些爬虫可以执行JavaScript，直接访问前端SPA即可，不需要SSR
    """
    if not user_agent:
        return False
    for pattern in JS_CAPABLE_CRAWLERS:
        if re.search(pattern, user_agent, re.IGNORECASE):
            return True
    return False

def is_crawler(user_agent: str) -> bool:
    """检测是否是任何类型的爬虫（兼容旧代码）"""
    return is_non_js_crawler(user_agent) or is_js_capable_crawler(user_agent)


def generate_html(
    title: str,
    description: str,
    image_url: str,
    page_url: str,
    site_name: str = "Link²Ur",
    body_content: str = "",
    structured_data: Optional[dict] = None
) -> str:
    """
    生成包含完整内容的 HTML（供AI爬虫和搜索引擎使用）
    不仅包含meta标签，还包含实际页面内容
    """
    
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
    
    # 清理描述（用于meta标签）
    meta_description = description
    if meta_description and len(meta_description) > 200:
        meta_description = meta_description[:200] + '...'
    
    # 清理 HTML 标签（用于meta标签）
    if meta_description:
        meta_description = re.sub(r'<[^>]+>', '', meta_description)
    
    # 生成结构化数据JSON
    structured_data_json = ""
    if structured_data:
        import json
        structured_data_json = f'<script type="application/ld+json">{json.dumps(structured_data, ensure_ascii=False)}</script>'
    
    # 如果没有提供body内容，生成默认内容
    if not body_content:
        body_content = f'''
    <main>
        <article>
            <h1>{title}</h1>
            <div class="content">
                <p>{description[:500] if len(description) > 500 else description}</p>
            </div>
            <p><a href="{page_url}">查看完整内容</a></p>
        </article>
    </main>'''
    
    html = f'''<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{title}</title>
    
    <!-- 基本 Meta -->
    <meta name="description" content="{meta_description}">
    <meta name="robots" content="index, follow">
    
    <!-- AI友好的meta标签 -->
    <meta name="summary" content="{meta_description}">
    <meta name="content-type" content="website">
    <meta name="geo.region" content="GB">
    <meta name="geo.placename" content="United Kingdom">
    
    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="{page_url}">
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{meta_description}">
    <meta property="og:image" content="{image_url}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:site_name" content="{site_name}">
    <meta property="og:locale" content="zh_CN">
    
    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:url" content="{page_url}">
    <meta name="twitter:title" content="{title}">
    <meta name="twitter:description" content="{meta_description}">
    <meta name="twitter:image" content="{image_url}">
    
    <!-- 微信分享 -->
    <meta name="weixin:title" content="{title}">
    <meta name="weixin:description" content="{meta_description}">
    <meta name="weixin:image" content="{image_url}">
    
    <!-- 结构化数据 -->
    {structured_data_json}
    
    <!-- 对于普通浏览器，延迟重定向（给爬虫时间抓取内容） -->
    <script>
        // 检测是否是爬虫（不执行JavaScript的爬虫不会执行这段代码）
        setTimeout(function() {{
            // 只有普通浏览器才会执行重定向
            if (document.referrer === '' || !navigator.userAgent.match(/bot|crawler|spider|crawling/i)) {{
                window.location.href = "{page_url}";
            }}
        }}, 100);
    </script>
    
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #fff;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }}
        header {{
            border-bottom: 2px solid #1890ff;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }}
        h1 {{
            font-size: 2em;
            color: #1890ff;
            margin-bottom: 10px;
        }}
        main {{
            margin: 20px 0;
        }}
        article {{
            background: #f9f9f9;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }}
        .content {{
            font-size: 1.1em;
            line-height: 1.8;
            margin: 20px 0;
        }}
        .content p {{
            margin-bottom: 15px;
        }}
        .meta-info {{
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 0.9em;
        }}
        a {{
            color: #1890ff;
            text-decoration: none;
        }}
        a:hover {{
            text-decoration: underline;
        }}
        img {{
            max-width: 100%;
            height: auto;
            border-radius: 4px;
            margin: 20px 0;
        }}
        footer {{
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #999;
            font-size: 0.9em;
        }}
    </style>
</head>
<body>
    <header>
        <h1>{site_name}</h1>
        <p>专业任务发布与技能匹配平台</p>
    </header>
    {body_content}
    <footer>
        <p>访问 <a href="{page_url}">{page_url}</a> 查看完整内容和交互功能</p>
        <p>需要JavaScript支持以获得最佳体验</p>
    </footer>
    <noscript>
        <div style="background: #fff3cd; border: 1px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
            <p><strong>提示：</strong>此页面需要JavaScript才能完整显示。以下是页面主要内容：</p>
            <h2>{title}</h2>
            <p>{description[:1000] if len(description) > 1000 else description}</p>
            <p><a href="{page_url}">点击访问完整页面</a></p>
        </div>
    </noscript>
</body>
</html>'''
    return html


# ==================== 主页 SSR ====================

@ssr_router.get("/")
@ssr_router.get("/zh")
@ssr_router.get("/en")
async def ssr_home(request: Request):
    """
    主页 SSR
    为AI爬虫提供主页的完整内容
    """
    user_agent = request.headers.get("User-Agent", "")
    
    # 如果不是爬虫，重定向到前端
    if not is_crawler(user_agent):
        path = request.url.path
        if path == "/zh" or path.startswith("/zh/"):
            return RedirectResponse(url="https://www.link2ur.com/zh", status_code=302)
        elif path == "/en" or path.startswith("/en/"):
            return RedirectResponse(url="https://www.link2ur.com/en", status_code=302)
        else:
            return RedirectResponse(url="https://www.link2ur.com/zh", status_code=302)
    
    # 构建主页内容
    title = "Link²Ur - 专业任务发布与技能匹配平台"
    description = "Link²Ur 是一个专业的任务发布与技能匹配平台，连接有技能的人与需要帮助的人。我们提供任务发布、技能匹配、跳蚤市场、社区论坛等功能，主要服务于英国的学生和专业人士。"
    
    body_content = '''
    <main>
        <article>
            <h1>欢迎来到 Link²Ur</h1>
            <div class="content">
                <p><strong>Link²Ur</strong> 是一个专业的任务发布与技能匹配平台，连接有技能的人与需要帮助的人。</p>
                
                <h2>主要功能</h2>
                <ul style="margin-left: 20px; line-height: 2;">
                    <li><strong>任务发布：</strong>发布任务，找到有技能的人来完成。支持一次性项目和持续职位。</li>
                    <li><strong>技能匹配：</strong>连接任务发布者与技能服务提供者，让价值创造更高效。</li>
                    <li><strong>跳蚤市场：</strong>在社区中买卖物品，支持二手交易。</li>
                    <li><strong>社区论坛：</strong>参与讨论，分享经验，获取帮助。</li>
                    <li><strong>自定义榜单：</strong>创建和参与各种主题的排行榜。</li>
                </ul>
                
                <h2>服务对象</h2>
                <p>主要服务于英国的学生和专业人士，包括：</p>
                <ul style="margin-left: 20px; line-height: 2;">
                    <li>在英国的学生</li>
                    <li>寻求自由职业的专业人士</li>
                    <li>需要服务的人群</li>
                    <li>社区成员</li>
                </ul>
                
                <h2>服务地区</h2>
                <p>主要服务地区：<strong>英国（United Kingdom）</strong></p>
                <p>主要城市：伦敦、伯明翰、曼彻斯特、爱丁堡、格拉斯哥等</p>
            </div>
            <div class="meta-info">
                <p><a href="https://www.link2ur.com">访问 Link²Ur 开始使用</a></p>
            </div>
        </article>
    </main>'''
    
    structured_data = {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": "Link²Ur",
        "url": "https://www.link2ur.com",
        "description": description,
        "potentialAction": {
            "@type": "SearchAction",
            "target": "https://www.link2ur.com/search?q={search_term_string}",
            "query-input": "required name=search_term_string"
        }
    }
    
    return HTMLResponse(
        content=generate_html(
            title=title,
            description=description,
            image_url="https://www.link2ur.com/static/favicon.png",
            page_url="https://www.link2ur.com",
            body_content=body_content,
            structured_data=structured_data
        )
    )


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
    
    # 如果是能执行JavaScript的现代爬虫，让它们直接访问前端SPA（执行JS）
    if is_js_capable_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/tasks/{task_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 如果不是不执行JS的爬虫，重定向到前端
    if not is_non_js_crawler(user_agent):
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
        
        # 清理描述中的HTML标签（用于显示）
        clean_description = re.sub(r'<[^>]+>', '', description) if description else ""
        
        # 获取任务图片
        image_url = ""
        if task.images and len(task.images) > 0:
            image_url = task.images[0]
        
        page_url = f"https://www.link2ur.com/zh/tasks/{task_id}"
        
        # 获取奖励信息
        reward = task.agreed_reward or task.base_reward or task.reward or 0
        reward_text = f"£{reward}" if reward > 0 else "面议"
        
        # 构建完整的HTML内容
        body_content = f'''
    <main>
        <article>
            <h1>{task.title}</h1>
            {f'<img src="{image_url}" alt="{task.title}" style="max-width: 100%; margin: 20px 0;">' if image_url else ''}
            <div class="content">
                <p><strong>任务类型：</strong>{task.task_type or "未指定"}</p>
                <p><strong>分类：</strong>{task.category or "未分类"}</p>
                <p><strong>位置：</strong>{task.location or "未指定"}</p>
                <p><strong>奖励：</strong>{reward_text}</p>
                {f'<p><strong>截止时间：</strong>{task.deadline.strftime("%Y-%m-%d %H:%M") if task.deadline else "未指定"}</p>' if task.deadline else ''}
                <div style="margin-top: 30px;">
                    <h2>任务描述</h2>
                    <p style="white-space: pre-wrap;">{clean_description[:2000]}{"..." if len(clean_description) > 2000 else ""}</p>
                </div>
            </div>
            <div class="meta-info">
                <p>任务ID: {task.id} | 创建时间: {task.created_at.strftime("%Y-%m-%d") if task.created_at else "未知"}</p>
                <p><a href="{page_url}">查看完整任务详情并申请</a></p>
            </div>
        </article>
    </main>'''
        
        # 构建结构化数据
        structured_data = {
            "@context": "https://schema.org",
            "@type": "JobPosting",
            "title": task.title,
            "description": clean_description[:1000],
            "identifier": {
                "@type": "PropertyValue",
                "name": "Link²Ur",
                "value": f"task-{task.id}"
            },
            "datePosted": task.created_at.isoformat() if task.created_at else None,
            "validThrough": task.deadline.isoformat() if task.deadline else None,
            "employmentType": "CONTRACTOR" if task.task_type == "one-off" else "PART_TIME",
            "hiringOrganization": {
                "@type": "Organization",
                "name": "Link²Ur",
                "sameAs": "https://www.link2ur.com"
            },
            "jobLocation": {
                "@type": "Place",
                "address": {
                    "@type": "PostalAddress",
                    "addressLocality": task.location or "London",
                    "addressCountry": "GB"
                }
            },
            "baseSalary": {
                "@type": "MonetaryAmount",
                "currency": "GBP",
                "value": {
                    "@type": "QuantitativeValue",
                    "value": reward,
                    "unitText": "ONE_TIME" if task.task_type == "one-off" else "HOUR"
                }
            } if reward > 0 else None
        }
        
        logger.info(f"SSR 任务详情: task_id={task_id}, title={task.title}, image={image_url}")
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=clean_description,
                image_url=image_url,
                page_url=page_url,
                body_content=body_content,
                structured_data=structured_data
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
    
    # 如果是能执行JavaScript的现代爬虫，让它们直接访问前端SPA（执行JS）
    if is_js_capable_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/leaderboard/custom/{leaderboard_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 如果不是不执行JS的爬虫，重定向到前端
    if not is_non_js_crawler(user_agent):
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
        clean_description = re.sub(r'<[^>]+>', '', description) if description else ""
        image_url = leaderboard.cover_image or ""
        page_url = f"https://www.link2ur.com/zh/leaderboard/custom/{leaderboard_id}"
        
        # 构建完整的HTML内容
        body_content = f'''
    <main>
        <article>
            <h1>{leaderboard.name}</h1>
            {f'<img src="{image_url}" alt="{leaderboard.name}" style="max-width: 100%; margin: 20px 0;">' if image_url else ''}
            <div class="content">
                <p><strong>榜单描述：</strong></p>
                <p style="white-space: pre-wrap;">{clean_description[:2000]}{"..." if len(clean_description) > 2000 else ""}</p>
                <p><strong>项目数量：</strong>{leaderboard.item_count or 0}</p>
            </div>
            <div class="meta-info">
                <p>榜单ID: {leaderboard.id} | 创建时间: {leaderboard.created_at.strftime("%Y-%m-%d") if leaderboard.created_at else "未知"}</p>
                <p><a href="{page_url}">查看完整榜单并参与投票</a></p>
            </div>
        </article>
    </main>'''
        
        logger.info(f"SSR 排行榜详情: id={leaderboard_id}, name={leaderboard.name}, image={image_url}")
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=clean_description,
                image_url=image_url,
                page_url=page_url,
                body_content=body_content
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
    
    # 如果是能执行JavaScript的现代爬虫，让它们直接访问前端SPA（执行JS）
    if is_js_capable_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/forum/post/{post_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 如果不是不执行JS的爬虫，重定向到前端
    if not is_non_js_crawler(user_agent):
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
        clean_description = re.sub(r'<[^>]+>', '', post.content or "")
        
        # 尝试从内容中提取第一张图片
        image_url = ""
        img_match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', post.content or "")
        if img_match:
            image_url = img_match.group(1)
        
        page_url = f"https://www.link2ur.com/zh/forum/post/{post_id}"
        
        # 构建完整的HTML内容
        body_content = f'''
    <main>
        <article>
            <h1>{post.title}</h1>
            {f'<img src="{image_url}" alt="{post.title}" style="max-width: 100%; margin: 20px 0;">' if image_url else ''}
            <div class="content">
                <p style="white-space: pre-wrap;">{clean_description[:2000]}{"..." if len(clean_description) > 2000 else ""}</p>
            </div>
            <div class="meta-info">
                <p>帖子ID: {post.id} | 创建时间: {post.created_at.strftime("%Y-%m-%d") if post.created_at else "未知"}</p>
                <p><a href="{page_url}">查看完整帖子并参与讨论</a></p>
            </div>
        </article>
    </main>'''
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=clean_description,
                image_url=image_url,
                page_url=page_url,
                body_content=body_content
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


# ==================== 活动详情页 SSR ====================

@ssr_router.get("/zh/activities/{activity_id}")
@ssr_router.get("/en/activities/{activity_id}")
@ssr_router.get("/activities/{activity_id}")
async def ssr_activity_detail(
    request: Request,
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency)
):
    """
    活动详情页 SSR
    - 如果是爬虫，返回包含正确 meta 标签的 HTML
    - 如果是普通用户，重定向到前端 SPA
    """
    user_agent = request.headers.get("User-Agent", "")
    
    # 调试日志：记录所有请求的 User-Agent（仅用于调试）
    logger.debug(f"活动详情 SSR 请求: activity_id={activity_id}, User-Agent={user_agent[:100] if user_agent else 'None'}")
    
    # 如果是能执行JavaScript的现代爬虫，让它们直接访问前端SPA（执行JS）
    if is_js_capable_crawler(user_agent):
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/activities/{activity_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/activities/{activity_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/activities/{activity_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 如果不是不执行JS的爬虫，重定向到前端
    if not is_non_js_crawler(user_agent):
        # 调试日志：记录被重定向的请求（用于排查 iOS 链接预览问题）
        logger.debug(f"活动详情 SSR: 非爬虫请求，重定向到前端 - User-Agent={user_agent[:150] if user_agent else 'None'}")
        path = request.url.path
        if path.startswith("/zh/"):
            frontend_url = f"https://www.link2ur.com/zh/activities/{activity_id}"
        elif path.startswith("/en/"):
            frontend_url = f"https://www.link2ur.com/en/activities/{activity_id}"
        else:
            frontend_url = f"https://www.link2ur.com/zh/activities/{activity_id}"
        return RedirectResponse(url=frontend_url, status_code=302)
    
    # 获取活动信息
    try:
        result = await db.execute(
            select(models.Activity).where(models.Activity.id == activity_id)
        )
        activity = result.scalar_one_or_none()
        
        if not activity:
            return HTMLResponse(
                content=generate_html(
                    title="活动不存在 - Link²Ur",
                    description="该活动可能已被删除或不存在",
                    image_url="",
                    page_url=f"https://www.link2ur.com/zh/activities/{activity_id}"
                ),
                status_code=404
            )
        
        # 构建分享信息
        title = f"{activity.title} - Link²Ur活动"
        description = activity.description or "在 Link²Ur 查看活动详情"
        
        # 清理描述中的HTML标签
        clean_description = re.sub(r'<[^>]+>', '', description) if description else ""
        
        # 获取活动图片（Activity 使用 images 数组，不是 cover_image）
        image_url = ""
        if activity.images and len(activity.images) > 0:
            # images 是 JSONB 数组，取第一张图片
            first_image = activity.images[0] if isinstance(activity.images, list) else None
            if first_image:
                image_url = first_image
        
        page_url = f"https://www.link2ur.com/zh/activities/{activity_id}"
        
        # 获取价格信息
        price = activity.discounted_price_per_participant or activity.original_price_per_participant or 0
        price_text = f"£{price}" if price > 0 else "免费"
        
        # 构建完整的HTML内容
        body_content = f'''
    <main>
        <article>
            <h1>{activity.title}</h1>
            {f'<img src="{image_url}" alt="{activity.title}" style="max-width: 100%; margin: 20px 0;">' if image_url else ''}
            <div class="content">
                <p><strong>活动类型：</strong>{activity.task_type or "未指定"}</p>
                <p><strong>位置：</strong>{activity.location or "未指定"}</p>
                <p><strong>价格：</strong>{price_text}/人</p>
                <p><strong>最小人数：</strong>{activity.min_participants or 1}人</p>
                <p><strong>最大人数：</strong>{activity.max_participants or "不限"}人</p>
                <div style="margin-top: 30px;">
                    <h2>活动描述</h2>
                    <p style="white-space: pre-wrap;">{clean_description[:2000]}{"..." if len(clean_description) > 2000 else ""}</p>
                </div>
            </div>
            <div class="meta-info">
                <p>活动ID: {activity.id} | 创建时间: {activity.created_at.strftime("%Y-%m-%d") if activity.created_at else "未知"}</p>
                <p><a href="{page_url}">查看完整活动详情并报名</a></p>
            </div>
        </article>
    </main>'''
        
        # 构建结构化数据
        structured_data = {
            "@context": "https://schema.org",
            "@type": "Event",
            "name": activity.title,
            "description": clean_description[:1000],
            "eventStatus": "https://schema.org/EventScheduled",
            "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode" if activity.location and activity.location.lower() != "online" else "https://schema.org/OnlineEventAttendanceMode",
            "location": {
                "@type": "Place",
                "name": activity.location or "London",
                "address": {
                    "@type": "PostalAddress",
                    "addressLocality": activity.location or "London",
                    "addressCountry": "GB"
                }
            },
            "organizer": {
                "@type": "Organization",
                "name": "Link²Ur",
                "url": "https://www.link2ur.com"
            },
            "offers": {
                "@type": "Offer",
                "price": str(price),
                "priceCurrency": "GBP",
                "availability": "https://schema.org/InStock"
            } if price > 0 else None,
            "image": image_url if image_url else None
        }
        
        logger.info(f"SSR 活动详情: activity_id={activity_id}, title={activity.title}, image={image_url}")
        
        return HTMLResponse(
            content=generate_html(
                title=title,
                description=clean_description,
                image_url=image_url,
                page_url=page_url,
                body_content=body_content,
                structured_data=structured_data
            )
        )
        
    except Exception as e:
        logger.error(f"SSR 活动详情失败: {e}")
        return HTMLResponse(
            content=generate_html(
                title="Link²Ur - 活动平台",
                description="发现精彩活动，与志同道合的人一起",
                image_url="",
                page_url=f"https://www.link2ur.com/zh/activities/{activity_id}"
            )
        )

