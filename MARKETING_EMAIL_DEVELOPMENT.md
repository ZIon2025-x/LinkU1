# 📧 营销邮件功能开发文档

## 📋 目录

1. [功能概述](#功能概述)
2. [技术架构](#技术架构)
3. [API接口设计](#api接口设计)
4. [实现步骤](#实现步骤)
5. [使用指南](#使用指南)
6. [配置说明](#配置说明)
7. [注意事项](#注意事项)
8. [测试指南](#测试指南)

---

## 🎯 功能概述

营销邮件功能允许管理员向用户发送批量营销邮件，支持：

- ✅ **批量发送**：向所有用户或指定用户组发送邮件
- ✅ **用户筛选**：按城市、语言偏好、用户等级等条件筛选
- ✅ **多语言支持**：根据用户语言偏好自动选择邮件语言
- ✅ **发送记录**：记录每次营销活动的发送状态
- ✅ **模板管理**：支持自定义HTML邮件模板
- ✅ **异步发送**：使用后台任务避免阻塞请求

---

## 🏗️ 技术架构

### 核心组件

```
营销邮件系统
├── 邮件模板 (email_templates.py)
│   └── get_marketing_email() - 生成营销邮件内容
├── 邮件发送 (email_utils.py)
│   └── send_email() - 智能邮件发送（Resend/SendGrid/SMTP）
├── API路由 (admin_marketing_routes.py)
│   ├── POST /api/admin/marketing/send - 发送营销邮件
│   ├── GET /api/admin/marketing/history - 查看发送历史
│   └── GET /api/admin/marketing/stats - 获取统计数据
└── 数据模型 (models.py)
    └── MarketingEmailCampaign - 营销活动记录表
```

### 技术栈

- **后端框架**：FastAPI
- **数据库**：PostgreSQL
- **邮件服务**：Resend（推荐）/ SendGrid / SMTP
- **异步任务**：FastAPI BackgroundTasks
- **认证**：管理员权限验证

---

## 🔌 API接口设计

### 1. 发送营销邮件

**接口**：`POST /api/admin/marketing/send`

**权限**：需要管理员权限

**请求体**：
```json
{
  "subject": "Link²Ur 特别优惠活动",
  "content": "<h1>欢迎参加我们的活动！</h1>",
  "target_users": {
    "all_users": false,
    "cities": ["London", "Manchester"],
    "language_preference": ["zh", "en"],
    "user_levels": ["normal", "vip"],
    "is_verified": true,
    "is_active": true
  },
  "send_immediately": true,
  "scheduled_time": null
}
```

**响应**：
```json
{
  "success": true,
  "campaign_id": 1,
  "total_users": 150,
  "message": "营销邮件已开始发送"
}
```

### 2. 查看发送历史

**接口**：`GET /api/admin/marketing/history`

**权限**：需要管理员权限

**查询参数**：
- `page`: 页码（默认1）
- `limit`: 每页数量（默认20）

**响应**：
```json
{
  "total": 10,
  "page": 1,
  "limit": 20,
  "campaigns": [
    {
      "id": 1,
      "subject": "Link²Ur 特别优惠活动",
      "total_users": 150,
      "sent_count": 150,
      "failed_count": 0,
      "created_at": "2024-01-15T10:00:00Z",
      "status": "completed"
    }
  ]
}
```

### 3. 获取统计数据

**接口**：`GET /api/admin/marketing/stats`

**权限**：需要管理员权限

**响应**：
```json
{
  "total_campaigns": 10,
  "total_emails_sent": 1500,
  "success_rate": 98.5,
  "recent_campaigns": [...]
}
```

---

## 🛠️ 实现步骤

### 步骤1：添加邮件模板

在 `backend/app/email_templates.py` 中添加营销邮件模板函数：

```python
def get_marketing_email(language: str, subject: str, content: str, unsubscribe_url: str = None) -> tuple[str, str]:
    """营销邮件模板"""
    header = get_email_header()
    
    # 根据语言生成邮件内容
    if language == 'zh':
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <div style="background: #ffffff; padding: 20px; border-radius: 8px;">
                    {content}
                </div>
                {f'<p style="text-align: center; margin-top: 30px;"><a href="{unsubscribe_url}" style="color: #666; font-size: 12px;">取消订阅</a></p>' if unsubscribe_url else ''}
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    此邮件由 Link²Ur 平台发送，请勿回复。
                </p>
            </div>
        </body>
        </html>
        """
    else:
        body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                {header}
                <div style="background: #ffffff; padding: 20px; border-radius: 8px;">
                    {content}
                </div>
                {f'<p style="text-align: center; margin-top: 30px;"><a href="{unsubscribe_url}" style="color: #666; font-size: 12px;">Unsubscribe</a></p>' if unsubscribe_url else ''}
                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    This email is sent by Link²Ur platform. Please do not reply.
                </p>
            </div>
        </body>
        </html>
        """
    
    return subject, body
```

### 步骤2：创建数据模型

在 `backend/app/models.py` 中添加营销活动记录表：

```python
class MarketingEmailCampaign(Base):
    """营销邮件活动记录表"""
    __tablename__ = "marketing_email_campaigns"
    
    id = Column(Integer, primary_key=True, index=True)
    subject = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    total_users = Column(Integer, default=0)
    sent_count = Column(Integer, default=0)
    failed_count = Column(Integer, default=0)
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    status = Column(String(20), default="pending")  # pending, sending, completed, failed
    target_filters = Column(JSONB, nullable=True)  # 存储筛选条件
    
    # 索引
    __table_args__ = (
        Index("ix_marketing_campaigns_created_at", created_at),
        Index("ix_marketing_campaigns_status", status),
    )
```

### 步骤3：添加Schema定义

在 `backend/app/schemas.py` 中添加：

```python
class MarketingEmailSend(BaseModel):
    """发送营销邮件请求"""
    subject: str = Field(..., min_length=1, max_length=200)
    content: str = Field(..., min_length=1)
    target_users: Optional[Dict[str, Any]] = Field(default=None, description="用户筛选条件")
    send_immediately: bool = Field(default=True)
    scheduled_time: Optional[datetime] = Field(default=None)

class MarketingEmailCampaignResponse(BaseModel):
    """营销活动响应"""
    id: int
    subject: str
    total_users: int
    sent_count: int
    failed_count: int
    created_at: datetime
    status: str
    
    class Config:
        from_attributes = True
```

### 步骤4：创建路由文件

创建 `backend/app/admin_marketing_routes.py`：

```python
"""
管理员营销邮件路由
提供营销邮件的发送、历史查看等功能
"""

import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from app.deps import get_sync_db
from app import models, schemas
from app.role_deps import get_current_admin_secure_sync
from app.email_utils import send_email
from app.email_templates import get_marketing_email
from app.config import Config
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

marketing_router = APIRouter(prefix="/api/admin/marketing", tags=["管理员-营销邮件"])

def filter_users_by_criteria(db: Session, filters: dict) -> List[models.User]:
    """根据筛选条件获取用户列表"""
    query = db.query(models.User)
    
    # 只发送给已验证且有邮箱的用户
    query = query.filter(models.User.is_verified == 1)
    query = query.filter(models.User.is_active == 1)
    query = query.filter(models.User.email.isnot(None))
    query = query.filter(models.User.email != "")
    
    if filters:
        if "cities" in filters and filters["cities"]:
            query = query.filter(models.User.residence_city.in_(filters["cities"]))
        
        if "language_preference" in filters and filters["language_preference"]:
            query = query.filter(models.User.language_preference.in_(filters["language_preference"]))
        
        if "user_levels" in filters and filters["user_levels"]:
            query = query.filter(models.User.user_level.in_(filters["user_levels"]))
        
        if "is_verified" in filters:
            query = query.filter(models.User.is_verified == (1 if filters["is_verified"] else 0))
        
        if "is_active" in filters:
            query = query.filter(models.User.is_active == (1 if filters["is_active"] else 0))
    
    return query.all()

def send_marketing_email_task(
    db: Session,
    campaign_id: int,
    user_emails: List[tuple[str, str]]  # (email, language)
):
    """后台任务：发送营销邮件"""
    try:
        campaign = db.query(models.MarketingEmailCampaign).filter(
            models.MarketingEmailCampaign.id == campaign_id
        ).first()
        
        if not campaign:
            logger.error(f"营销活动不存在: {campaign_id}")
            return
        
        campaign.status = "sending"
        db.commit()
        
        sent_count = 0
        failed_count = 0
        
        for email, language in user_emails:
            try:
                # 生成取消订阅链接
                unsubscribe_url = f"{Config.FRONTEND_URL}/unsubscribe?email={email}&token=..."
                
                # 获取邮件模板
                subject, body = get_marketing_email(
                    language=language,
                    subject=campaign.subject,
                    content=campaign.content,
                    unsubscribe_url=unsubscribe_url
                )
                
                # 发送邮件
                if send_email(email, subject, body):
                    sent_count += 1
                else:
                    failed_count += 1
                    
            except Exception as e:
                logger.error(f"发送邮件失败 {email}: {e}")
                failed_count += 1
        
        # 更新活动状态
        campaign.sent_count = sent_count
        campaign.failed_count = failed_count
        campaign.status = "completed"
        db.commit()
        
        logger.info(f"营销活动 {campaign_id} 完成: 成功 {sent_count}, 失败 {failed_count}")
        
    except Exception as e:
        logger.error(f"发送营销邮件任务失败: {e}")
        if campaign:
            campaign.status = "failed"
            db.commit()

@marketing_router.post("/send", response_model=dict)
def send_marketing_email(
    email_data: schemas.MarketingEmailSend,
    background_tasks: BackgroundTasks,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """发送营销邮件"""
    try:
        # 获取目标用户
        filters = email_data.target_users or {}
        users = filter_users_by_criteria(db, filters)
        
        if not users:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="没有符合条件的用户"
            )
        
        # 创建营销活动记录
        campaign = models.MarketingEmailCampaign(
            subject=email_data.subject,
            content=email_data.content,
            total_users=len(users),
            created_by=current_admin.id,
            target_filters=filters,
            status="pending"
        )
        db.add(campaign)
        db.commit()
        db.refresh(campaign)
        
        # 准备用户邮箱和语言列表
        user_emails = [
            (user.email, user.language_preference or "en")
            for user in users
            if user.email
        ]
        
        # 添加到后台任务
        background_tasks.add_task(
            send_marketing_email_task,
            db=db,
            campaign_id=campaign.id,
            user_emails=user_emails
        )
        
        return {
            "success": True,
            "campaign_id": campaign.id,
            "total_users": len(users),
            "message": "营销邮件已开始发送"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送营销邮件失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"发送失败: {str(e)}"
        )

@marketing_router.get("/history", response_model=dict)
def get_marketing_history(
    page: int = 1,
    limit: int = 20,
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """获取营销邮件发送历史"""
    try:
        offset = (page - 1) * limit
        
        # 查询总数
        total = db.query(models.MarketingEmailCampaign).count()
        
        # 查询列表
        campaigns = db.query(models.MarketingEmailCampaign)\
            .order_by(models.MarketingEmailCampaign.created_at.desc())\
            .offset(offset)\
            .limit(limit)\
            .all()
        
        return {
            "total": total,
            "page": page,
            "limit": limit,
            "campaigns": [
                {
                    "id": c.id,
                    "subject": c.subject,
                    "total_users": c.total_users,
                    "sent_count": c.sent_count,
                    "failed_count": c.failed_count,
                    "created_at": c.created_at.isoformat(),
                    "status": c.status
                }
                for c in campaigns
            ]
        }
        
    except Exception as e:
        logger.error(f"获取营销历史失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取失败: {str(e)}"
        )

@marketing_router.get("/stats", response_model=dict)
def get_marketing_stats(
    current_admin: models.AdminUser = Depends(get_current_admin_secure_sync),
    db: Session = Depends(get_sync_db),
):
    """获取营销邮件统计数据"""
    try:
        campaigns = db.query(models.MarketingEmailCampaign).all()
        
        total_campaigns = len(campaigns)
        total_emails_sent = sum(c.sent_count for c in campaigns)
        total_emails_failed = sum(c.failed_count for c in campaigns)
        total_attempts = total_emails_sent + total_emails_failed
        
        success_rate = (total_emails_sent / total_attempts * 100) if total_attempts > 0 else 0
        
        # 最近5个活动
        recent_campaigns = db.query(models.MarketingEmailCampaign)\
            .order_by(models.MarketingEmailCampaign.created_at.desc())\
            .limit(5)\
            .all()
        
        return {
            "total_campaigns": total_campaigns,
            "total_emails_sent": total_emails_sent,
            "total_emails_failed": total_emails_failed,
            "success_rate": round(success_rate, 2),
            "recent_campaigns": [
                {
                    "id": c.id,
                    "subject": c.subject,
                    "status": c.status,
                    "sent_count": c.sent_count,
                    "created_at": c.created_at.isoformat()
                }
                for c in recent_campaigns
            ]
        }
        
    except Exception as e:
        logger.error(f"获取营销统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取失败: {str(e)}"
        )
```

### 步骤5：注册路由

在 `backend/app/main.py` 中添加：

```python
# 营销邮件路由
from app.admin_marketing_routes import marketing_router
app.include_router(marketing_router, tags=["管理员-营销邮件"])
```

### 步骤6：数据库迁移

创建迁移脚本或直接在数据库中执行：

```sql
CREATE TABLE IF NOT EXISTS marketing_email_campaigns (
    id SERIAL PRIMARY KEY,
    subject VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    total_users INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    created_by VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'pending',
    target_filters JSONB
);

CREATE INDEX IF NOT EXISTS ix_marketing_campaigns_created_at ON marketing_email_campaigns(created_at);
CREATE INDEX IF NOT EXISTS ix_marketing_campaigns_status ON marketing_email_campaigns(status);
```

---

## 📖 使用指南

### 1. 发送给所有用户

```bash
curl -X POST "http://localhost:8000/api/admin/marketing/send" \
  -H "Content-Type: application/json" \
  -H "Cookie: access_token=..." \
  -d '{
    "subject": "Link²Ur 特别优惠",
    "content": "<h1>欢迎参加活动！</h1><p>限时优惠...</p>",
    "target_users": {},
    "send_immediately": true
  }'
```

### 2. 发送给特定城市用户

```bash
curl -X POST "http://localhost:8000/api/admin/marketing/send" \
  -H "Content-Type: application/json" \
  -H "Cookie: access_token=..." \
  -d '{
    "subject": "伦敦用户专享",
    "content": "<h1>伦敦用户专享优惠</h1>",
    "target_users": {
      "cities": ["London"]
    },
    "send_immediately": true
  }'
```

### 3. 发送给中文用户

```bash
curl -X POST "http://localhost:8000/api/admin/marketing/send" \
  -H "Content-Type: application/json" \
  -H "Cookie: access_token=..." \
  -d '{
    "subject": "Link²Ur 特别优惠",
    "content": "<h1>欢迎参加活动！</h1>",
    "target_users": {
      "language_preference": ["zh"]
    },
    "send_immediately": true
  }'
```

### 4. 查看发送历史

```bash
curl -X GET "http://localhost:8000/api/admin/marketing/history?page=1&limit=20" \
  -H "Cookie: access_token=..."
```

### 5. 获取统计数据

```bash
curl -X GET "http://localhost:8000/api/admin/marketing/stats" \
  -H "Cookie: access_token=..."
```

---

## ⚙️ 配置说明

### 环境变量

确保以下环境变量已配置（参考 `EMAIL_CONFIG_GUIDE.md`）：

```env
# Resend配置（推荐）
USE_RESEND=true
RESEND_API_KEY=your-resend-api-key
EMAIL_FROM=noreply@link2ur.com

# 或 SendGrid配置
USE_SENDGRID=true
SENDGRID_API_KEY=your-sendgrid-api-key

# 或 SMTP配置
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-password
SMTP_USE_TLS=true
```

### 邮件服务优先级

系统按以下顺序选择邮件服务：

1. **Resend**（如果配置了 `RESEND_API_KEY`）
2. **SendGrid**（如果配置了 `SENDGRID_API_KEY`）
3. **SMTP**（作为最后备选）

---

## ⚠️ 注意事项

### 1. 邮件发送限制

- **Resend免费版**：每月3000封邮件
- **SendGrid免费版**：每天100封邮件
- **SMTP**：取决于服务商限制

### 2. 用户筛选

- 只发送给已验证邮箱的用户（`is_verified = 1`）
- 只发送给活跃用户（`is_active = 1`）
- 必须有有效的邮箱地址

### 3. 批量发送

- 使用后台任务异步发送，避免阻塞请求
- 大量用户时建议分批发送
- 监控发送状态和失败率

### 4. 法律合规

- 遵守GDPR等数据保护法规
- 提供取消订阅功能
- 不要发送垃圾邮件
- 尊重用户隐私

### 5. 性能优化

- 大量用户时考虑使用Celery等任务队列
- 限制并发发送数量
- 添加重试机制

---

## 🧪 测试指南

### 1. 单元测试

```python
def test_send_marketing_email():
    """测试发送营销邮件"""
    # 创建测试用户
    # 发送测试邮件
    # 验证邮件发送成功
    pass

def test_filter_users():
    """测试用户筛选"""
    # 创建不同条件的用户
    # 测试筛选功能
    # 验证结果正确
    pass
```

### 2. 集成测试

```bash
# 1. 测试发送给单个用户
curl -X POST "http://localhost:8000/api/admin/marketing/send" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "测试邮件",
    "content": "<p>这是测试内容</p>",
    "target_users": {"cities": ["London"]}
  }'

# 2. 检查发送历史
curl -X GET "http://localhost:8000/api/admin/marketing/history"

# 3. 检查统计数据
curl -X GET "http://localhost:8000/api/admin/marketing/stats"
```

### 3. 邮件服务测试

确保邮件服务配置正确：

```python
# 测试Resend
from app.email_utils import send_email_resend
send_email_resend("test@example.com", "测试", "<p>测试内容</p>")

# 测试SendGrid
from app.email_utils import send_email_sendgrid
send_email_sendgrid("test@example.com", "测试", "<p>测试内容</p>")

# 测试SMTP
from app.email_utils import send_email_smtp
send_email_smtp("test@example.com", "测试", "<p>测试内容</p>")
```

---

## 📚 相关文档

- [邮箱配置指南](./EMAIL_CONFIG_GUIDE.md)
- [Resend设置指南](./backend/RESEND_SETUP_GUIDE.md)
- [管理员认证文档](./backend/ADMIN_LOGIN_SETUP_GUIDE.md)

---

## 🔄 更新日志

### v1.0.0 (2024-01-15)
- ✅ 初始版本发布
- ✅ 支持批量发送营销邮件
- ✅ 支持用户筛选功能
- ✅ 支持多语言邮件
- ✅ 发送历史记录
- ✅ 统计数据功能

---

## 💡 未来改进

- [ ] 支持邮件模板管理
- [ ] 支持定时发送
- [ ] 支持A/B测试
- [ ] 支持邮件打开率追踪
- [ ] 支持点击率统计
- [ ] 支持取消订阅管理
- [ ] 支持邮件预览功能
- [ ] 集成Celery任务队列

---

## 📞 技术支持

如有问题，请联系开发团队或查看相关文档。











