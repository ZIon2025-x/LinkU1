# 官方账号与官方活动 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 添加官方达人账号（置顶达人列表）及官方活动（抽奖/抢位），支持积分/实物/券码/线下到场四种奖品。

**Architecture:** 扩展现有 TaskExpert + Activity 模型（最小化改动），新建 OfficialActivityApplication 表处理官方活动报名（绕过付款流程），新增 admin 管理端点 + 用户端点，Flutter/iOS 复用现有页面并按 activityType 动态渲染。

**Tech Stack:** Python FastAPI + SQLAlchemy (async) + PostgreSQL + 自定义 task scheduler；Flutter BLoC；iOS SwiftUI + Combine

---

## 概览

| Phase | 内容 |
|-------|------|
| 1 | 后端：数据库 Schema 变更 |
| 2 | 后端：Schemas（Pydantic） |
| 3 | 后端：Admin API（官方账号 + 官方活动 CRUD + 开奖） |
| 4 | 后端：用户 API（报名/取消/结果）+ 调度器 |
| 5 | Flutter：模型 + BLoC + UI |
| 6 | iOS：模型 + API + ViewModel + UI |

---

## Phase 1：后端数据库 Schema

### Task 1：给 task_experts 表加官方字段

**Files:**
- Modify: `backend/app/models.py` (TaskExpert class, around line 1494)

**Step 1：在 TaskExpert 类加字段**

在 `updated_at` 字段之后加：
```python
is_official = Column(Boolean, default=False, nullable=False)
official_badge = Column(String(50), nullable=True)
```

**Step 2：在 Railway PostgreSQL 执行 ALTER TABLE**

通过 Railway console 或 psql 运行：
```sql
ALTER TABLE task_experts
  ADD COLUMN IF NOT EXISTS is_official BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS official_badge VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_task_experts_is_official ON task_experts(is_official);
```

**Step 3：验证**

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'task_experts' AND column_name IN ('is_official', 'official_badge');
```
Expected: 2 rows returned.

**Step 4：Commit**
```bash
git add backend/app/models.py
git commit -m "feat(db): add is_official and official_badge to task_experts"
```

---

### Task 2：给 activities 表加官方活动字段

**Files:**
- Modify: `backend/app/models.py` (Activity class, around line 1973)

**Step 1：修改 expert_service_id 为可选**

找到：
```python
expert_service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="RESTRICT"), nullable=False)
```
改为：
```python
expert_service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="RESTRICT"), nullable=True)
```

**Step 2：在 Activity 类的 `updated_at` 之后加新字段**
```python
# 官方活动字段
activity_type = Column(String(20), nullable=False, default="standard")  # standard/lottery/first_come
prize_type = Column(String(20), nullable=True)   # points/physical/voucher_code/in_person
prize_description = Column(Text, nullable=True)
prize_description_en = Column(Text, nullable=True)
prize_count = Column(Integer, nullable=True)      # 中奖名额数 / 抢位数
voucher_codes = Column(JSONB, nullable=True)      # ["CODE1","CODE2",...]

# 抽奖字段
draw_mode = Column(String(10), nullable=True)     # auto/manual
draw_at = Column(DateTime, nullable=True)         # 自动开奖时间
drawn_at = Column(DateTime, nullable=True)        # 实际开奖时间
winners = Column(JSONB, nullable=True)            # [{user_id, name, prize_index}]
is_drawn = Column(Boolean, default=False, nullable=False)
```

**Step 3：执行 ALTER TABLE**
```sql
ALTER TABLE activities
  ALTER COLUMN expert_service_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS activity_type VARCHAR(20) NOT NULL DEFAULT 'standard',
  ADD COLUMN IF NOT EXISTS prize_type VARCHAR(20),
  ADD COLUMN IF NOT EXISTS prize_description TEXT,
  ADD COLUMN IF NOT EXISTS prize_description_en TEXT,
  ADD COLUMN IF NOT EXISTS prize_count INTEGER,
  ADD COLUMN IF NOT EXISTS voucher_codes JSONB,
  ADD COLUMN IF NOT EXISTS draw_mode VARCHAR(10),
  ADD COLUMN IF NOT EXISTS draw_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS drawn_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS winners JSONB,
  ADD COLUMN IF NOT EXISTS is_drawn BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_activities_activity_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_draw_at ON activities(draw_at) WHERE is_drawn = FALSE;
```

**Step 4：Commit**
```bash
git add backend/app/models.py
git commit -m "feat(db): add official activity fields to activities table"
```

---

### Task 3：创建 official_activity_applications 表

**Files:**
- Modify: `backend/app/models.py` (after Activity class)

**Step 1：在 models.py 末尾（Activity 类之后）加模型**
```python
class OfficialActivityApplication(Base):
    __tablename__ = "official_activity_applications"

    id = Column(Integer, primary_key=True, index=True)
    activity_id = Column(Integer, ForeignKey("activities.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    applied_at = Column(DateTime, default=get_utc_time, nullable=False)
    status = Column(String(20), default="pending", nullable=False)
    # status: pending / won / lost / attending
    prize_index = Column(Integer, nullable=True)   # 对应 voucher_codes[prize_index]
    notified_at = Column(DateTime, nullable=True)

    __table_args__ = (
        UniqueConstraint("activity_id", "user_id", name="uq_official_app_activity_user"),
        CheckConstraint(
            "status IN ('pending','won','lost','attending')",
            name="ck_official_app_status"
        ),
    )

    # Relationships
    activity = relationship("Activity", backref="official_applications")
    user = relationship("User", backref="official_activity_applications")
```

**Step 2：执行 CREATE TABLE**
```sql
CREATE TABLE IF NOT EXISTS official_activity_applications (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    applied_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','won','lost','attending')),
    prize_index INTEGER,
    notified_at TIMESTAMP,
    CONSTRAINT uq_official_app_activity_user UNIQUE (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_official_apps_activity_id ON official_activity_applications(activity_id);
CREATE INDEX IF NOT EXISTS idx_official_apps_user_id ON official_activity_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_official_apps_status ON official_activity_applications(activity_id, status);
```

**Step 3：Commit**
```bash
git add backend/app/models.py
git commit -m "feat(db): add OfficialActivityApplication model"
```

---

## Phase 2：后端 Schemas

### Task 4：更新 TaskExpert schemas

**Files:**
- Modify: `backend/app/schemas.py` (TaskExpertOut class, around line 2098)

**Step 1：在 TaskExpertOut 加字段**

找到 `TaskExpertOut` 类，在现有字段后加：
```python
is_official: bool = False
official_badge: Optional[str] = None
```

**Step 2：Commit**
```bash
git add backend/app/schemas.py
git commit -m "feat(schema): add is_official fields to TaskExpertOut"
```

---

### Task 5：更新 Activity schemas + 新增官方活动 schemas

**Files:**
- Modify: `backend/app/schemas.py`

**Step 1：在 ActivityOut 类加新字段**

找到 `ActivityOut` 类，在现有字段后加：
```python
activity_type: str = "standard"
prize_type: Optional[str] = None
prize_description: Optional[str] = None
prize_description_en: Optional[str] = None
prize_count: Optional[int] = None
draw_mode: Optional[str] = None
draw_at: Optional[datetime] = None
drawn_at: Optional[datetime] = None
winners: Optional[List[dict]] = None
is_drawn: bool = False
is_official: bool = False   # 计算字段：来自 expert.is_official
current_applicants: Optional[int] = None  # 官方活动用，计算字段
```

**Step 2：在 schemas.py 末尾加官方活动 schemas**
```python
# ---------- Official Activity Schemas ----------

class ActivityWinner(BaseModel):
    user_id: str
    name: str
    avatar_url: Optional[str] = None
    prize_index: Optional[int] = None

class OfficialActivityCreate(BaseModel):
    title: str
    title_en: Optional[str] = None
    title_zh: Optional[str] = None
    description: str
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
    location: Optional[str] = None
    activity_type: str  # "lottery" or "first_come"
    prize_type: str     # "points" / "physical" / "voucher_code" / "in_person"
    prize_description: Optional[str] = None
    prize_description_en: Optional[str] = None
    prize_count: int
    voucher_codes: Optional[List[str]] = None
    draw_mode: Optional[str] = None   # "auto" / "manual" (lottery only)
    draw_at: Optional[datetime] = None  # auto draw time (lottery only)
    deadline: Optional[datetime] = None
    images: Optional[List[str]] = None
    is_public: bool = True

class OfficialActivityUpdate(BaseModel):
    title: Optional[str] = None
    title_en: Optional[str] = None
    description: Optional[str] = None
    description_en: Optional[str] = None
    prize_description: Optional[str] = None
    prize_count: Optional[int] = None
    voucher_codes: Optional[List[str]] = None
    draw_at: Optional[datetime] = None
    deadline: Optional[datetime] = None
    images: Optional[List[str]] = None
    status: Optional[str] = None

class OfficialActivityApplicationOut(BaseModel):
    id: int
    activity_id: int
    user_id: str
    applied_at: datetime
    status: str
    prize_index: Optional[int] = None
    notified_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class OfficialActivityResultOut(BaseModel):
    is_drawn: bool
    drawn_at: Optional[datetime] = None
    winners: List[ActivityWinner] = []
    my_status: Optional[str] = None    # pending/won/lost
    my_voucher_code: Optional[str] = None

class OfficialAccountSetup(BaseModel):
    user_id: str
    official_badge: Optional[str] = "官方"
```

**Step 3：Commit**
```bash
git add backend/app/schemas.py
git commit -m "feat(schema): add official activity schemas"
```

---

## Phase 3：后端 Admin API

### Task 6：创建 admin_official_routes.py

**Files:**
- Create: `backend/app/admin_official_routes.py`

**Step 1：创建文件**
```python
"""
管理员 - 官方账号 & 官方活动管理
"""
import random
from datetime import datetime
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils import get_utc_time

# 复用现有 admin auth
from app.separate_auth import get_current_admin_user

admin_official_router = APIRouter(
    prefix="/api/admin/official",
    tags=["admin-official"],
)


# ── 官方账号管理 ───────────────────────────────────────

@admin_official_router.post("/account/setup", response_model=dict)
async def setup_official_account(
    data: schemas.OfficialAccountSetup,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    """将指定用户设为官方达人账号"""
    # 验证用户存在
    user_result = await db.execute(
        select(models.User).where(models.User.id == data.user_id)
    )
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 查找或创建 TaskExpert 记录
    expert_result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.id == data.user_id)
    )
    expert = expert_result.scalar_one_or_none()

    if not expert:
        expert = models.TaskExpert(
            id=data.user_id,
            expert_name=user.name,
            status="active",
            rating=5.0,
            total_services=0,
            completed_tasks=0,
        )
        db.add(expert)

    expert.is_official = True
    expert.official_badge = data.official_badge or "官方"
    await db.commit()
    return {"success": True, "user_id": data.user_id, "badge": expert.official_badge}


@admin_official_router.get("/account", response_model=dict)
async def get_official_account(
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    """获取当前官方账号信息"""
    result = await db.execute(
        select(models.TaskExpert, models.User)
        .join(models.User, models.User.id == models.TaskExpert.id)
        .where(models.TaskExpert.is_official == True)
    )
    row = result.first()
    if not row:
        return {"official_account": None}
    expert, user = row
    return {
        "official_account": {
            "user_id": expert.id,
            "name": user.name,
            "badge": expert.official_badge,
            "avatar": expert.avatar,
            "status": expert.status,
        }
    }


# ── 官方活动 CRUD ──────────────────────────────────────

async def _get_official_expert(db: AsyncSession) -> models.TaskExpert:
    """获取官方达人账号，不存在则报错"""
    result = await db.execute(
        select(models.TaskExpert).where(models.TaskExpert.is_official == True)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(
            status_code=400,
            detail="尚未设置官方账号，请先调用 /api/admin/official/account/setup"
        )
    return expert


@admin_official_router.post("/activities", response_model=schemas.ActivityOut)
async def create_official_activity(
    data: schemas.OfficialActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    """创建官方活动（抽奖 or 抢位）"""
    expert = await _get_official_expert(db)

    # 验证：抽奖活动必须有 draw_mode 和 prize_count
    if data.activity_type == "lottery" and not data.draw_mode:
        raise HTTPException(status_code=400, detail="抽奖活动必须指定 draw_mode")
    if data.activity_type == "lottery" and data.draw_mode == "auto" and not data.draw_at:
        raise HTTPException(status_code=400, detail="自动开奖必须指定 draw_at")
    if data.prize_type == "voucher_code" and data.voucher_codes:
        if len(data.voucher_codes) < data.prize_count:
            raise HTTPException(
                status_code=400,
                detail=f"券码数量({len(data.voucher_codes)})少于奖品数量({data.prize_count})"
            )

    activity = models.Activity(
        title=data.title,
        title_en=data.title_en,
        title_zh=data.title_zh,
        description=data.description,
        description_en=data.description_en,
        description_zh=data.description_zh,
        location=data.location or "",
        expert_id=expert.id,
        expert_service_id=None,         # 官方活动不绑服务
        activity_type=data.activity_type,
        prize_type=data.prize_type,
        prize_description=data.prize_description,
        prize_description_en=data.prize_description_en,
        prize_count=data.prize_count,
        voucher_codes=data.voucher_codes,
        draw_mode=data.draw_mode,
        draw_at=data.draw_at,
        is_drawn=False,
        status="open",
        is_public=data.is_public,
        max_participants=data.prize_count * 10,  # 默认最多报名人数
        min_participants=1,
        completion_rule="min",
        reward_distribution="equal",
        reward_type="points" if data.prize_type == "points" else "cash",
        currency="GBP",
        has_time_slots=False,
        deadline=data.draw_at or data.deadline,
        images=data.images,
        task_type="official",
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)
    return activity


@admin_official_router.put("/activities/{activity_id}", response_model=schemas.ActivityOut)
async def update_official_activity(
    activity_id: int,
    data: schemas.OfficialActivityUpdate,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"])
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="官方活动不存在")
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail="已开奖的活动不能修改")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(activity, field, value)
    await db.commit()
    await db.refresh(activity)
    return activity


@admin_official_router.delete("/activities/{activity_id}", response_model=dict)
async def cancel_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    activity.status = "cancelled"
    await db.commit()
    return {"success": True}


@admin_official_router.get("/activities/{activity_id}/applicants", response_model=dict)
async def get_activity_applicants(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    result = await db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(models.OfficialActivityApplication.activity_id == activity_id)
        .order_by(models.OfficialActivityApplication.applied_at)
    )
    rows = result.all()
    return {
        "total": len(rows),
        "applicants": [
            {
                "user_id": app.user_id,
                "name": user.name,
                "status": app.status,
                "applied_at": app.applied_at.isoformat(),
                "prize_index": app.prize_index,
            }
            for app, user in rows
        ]
    }


# ── 手动开奖 ───────────────────────────────────────────

@admin_official_router.post("/activities/{activity_id}/draw", response_model=dict)
async def manual_draw(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    admin: models.AdminUser = Depends(get_current_admin_user),
):
    """手动触发开奖"""
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type == "lottery"
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="抽奖活动不存在")
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail="已开过奖")

    winners = await _perform_draw(db, activity)
    return {"success": True, "winner_count": len(winners), "winners": winners}
```

**Step 2：实现 `_perform_draw` 函数（加在同文件末尾）**
```python
async def _perform_draw(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """
    核心开奖逻辑：
    1. 随机抽取 prize_count 个 pending 报名者
    2. 更新 status: won/lost
    3. 分配券码
    4. 发站内通知
    5. 更新 activity.is_drawn, drawn_at, winners
    """
    from app.crud.notification import create_notification

    # 获取所有 pending 报名
    apps_result = await db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending"
        )
    )
    all_apps = apps_result.all()

    prize_count = activity.prize_count or 1
    selected = random.sample(all_apps, min(prize_count, len(all_apps)))
    selected_ids = {app.user_id for app, _ in selected}

    winners_data = []
    voucher_codes = activity.voucher_codes or []

    for i, (app, user) in enumerate(selected):
        app.status = "won"
        app.notified_at = get_utc_time()
        if activity.prize_type == "voucher_code" and i < len(voucher_codes):
            app.prize_index = i

        winners_data.append({
            "user_id": app.user_id,
            "name": user.name,
            "prize_index": app.prize_index,
        })

        # 发站内通知
        prize_desc = activity.prize_description or "奖品"
        voucher_info = f"\n您的优惠码：{voucher_codes[i]}" if app.prize_index is not None and i < len(voucher_codes) else ""
        create_notification(
            db=db,
            user_id=app.user_id,
            type="official_activity_won",
            title="🎉 恭喜中奖！",
            content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
            title_en="🎉 Congratulations!",
            content_en=f"You won in '{activity.title_en or activity.title}'! Prize: {activity.prize_description_en or prize_desc}{voucher_info}",
            related_id=str(activity.id),
            related_type="activity_id",
            auto_commit=False,
        )

    # 未中奖的改为 lost
    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    # 更新活动
    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"

    await db.commit()
    return winners_data
```

**Step 3：在 main.py 注册路由**

打开 `backend/app/main.py`，找到其他 `app.include_router(...)` 调用，加入：
```python
from app.admin_official_routes import admin_official_router
app.include_router(admin_official_router)
```

**Step 4：Commit**
```bash
git add backend/app/admin_official_routes.py backend/app/main.py
git commit -m "feat(api): add admin official account and activity management endpoints"
```

---

## Phase 4：用户 API + 调度器

### Task 7：创建 official_activity_routes.py（用户端）

**Files:**
- Create: `backend/app/official_activity_routes.py`

**Step 1：创建文件**
```python
"""
用户端 - 官方活动报名/取消/结果
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.secure_auth import get_current_user_secure_async_csrf
from app.utils import get_utc_time

official_activity_router = APIRouter(
    prefix="/api/official-activities",
    tags=["official-activities"],
)


@official_activity_router.post("/{activity_id}/apply", response_model=dict)
async def apply_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """报名官方活动（抽奖/抢位均用此接口）"""
    # 获取活动
    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
            models.Activity.status == "open",
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在或已结束")

    # 检查是否已报名
    existing = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="您已报名此活动")

    # 抢位活动：检查名额
    if activity.activity_type == "first_come":
        count_result = await db.execute(
            select(func.count()).where(
                models.OfficialActivityApplication.activity_id == activity_id,
                models.OfficialActivityApplication.status == "attending",
            )
        )
        current_count = count_result.scalar() or 0
        if current_count >= (activity.prize_count or 0):
            raise HTTPException(status_code=400, detail="名额已满")

        app = models.OfficialActivityApplication(
            activity_id=activity_id,
            user_id=current_user.id,
            status="attending",  # 抢位直接成功
        )
    else:
        # 抽奖：pending 等待开奖
        app = models.OfficialActivityApplication(
            activity_id=activity_id,
            user_id=current_user.id,
            status="pending",
        )

    db.add(app)
    await db.commit()
    return {
        "success": True,
        "status": app.status,
        "message": "报名成功，等待开奖" if app.status == "pending" else "报名成功！"
    }


@official_activity_router.delete("/{activity_id}/apply", response_model=dict)
async def cancel_official_activity_application(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """取消报名（截止前可取消）"""
    result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    app = result.scalar_one_or_none()
    if not app:
        raise HTTPException(status_code=404, detail="未找到报名记录")
    if app.status in ("won", "lost"):
        raise HTTPException(status_code=400, detail="已开奖，无法取消")

    await db.delete(app)
    await db.commit()
    return {"success": True}


@official_activity_router.get("/{activity_id}/result", response_model=schemas.OfficialActivityResultOut)
async def get_official_activity_result(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """查看开奖结果（含我的状态）"""
    act_result = await db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )
    activity = act_result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在")

    # 我的报名状态
    my_app_result = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
        )
    )
    my_app = my_app_result.scalar_one_or_none()

    my_voucher = None
    if my_app and my_app.status == "won" and my_app.prize_index is not None:
        codes = activity.voucher_codes or []
        if my_app.prize_index < len(codes):
            my_voucher = codes[my_app.prize_index]

    winners = []
    if activity.winners:
        winners = [
            schemas.ActivityWinner(
                user_id=w["user_id"],
                name=w["name"],
                prize_index=w.get("prize_index"),
            )
            for w in activity.winners
        ]

    return schemas.OfficialActivityResultOut(
        is_drawn=activity.is_drawn,
        drawn_at=activity.drawn_at,
        winners=winners,
        my_status=my_app.status if my_app else None,
        my_voucher_code=my_voucher,
    )
```

**Step 2：在 main.py 注册**
```python
from app.official_activity_routes import official_activity_router
app.include_router(official_activity_router)
```

**Step 3：修改达人列表查询，官方账号置顶**

找到 `backend/app/task_expert_routes.py` 中处理达人列表的查询（搜索 `GET /api/task-experts`，找到 `select(models.TaskExpert)` 的地方）。在 `order_by` 中加官方账号排序：

```python
# 在现有 order_by 前面加：
.order_by(
    models.TaskExpert.is_official.desc(),  # 官方账号排最前
    # ... 原有排序条件
)
```

**Step 4：修改 ActivityOut 序列化，加 is_official 和 current_applicants**

找到达人活动列表或详情的路由，在序列化 Activity 时加计算字段（参考现有代码加法即可）。如果用 response_model，需要在返回前手动把 expert.is_official 赋给 activity 的虚拟字段，或者改为返回 dict。

具体做法：在返回 activity 的地方：
```python
# 获取 expert 信息
expert = await db.get(models.TaskExpert, activity.expert_id)
result_dict = {
    **activity.__dict__,
    "is_official": expert.is_official if expert else False,
    "current_applicants": await db.scalar(
        select(func.count()).where(
            models.OfficialActivityApplication.activity_id == activity.id
        )
    ) if activity.activity_type in ("lottery", "first_come") else None,
}
```

**Step 5：Commit**
```bash
git add backend/app/official_activity_routes.py backend/app/main.py backend/app/task_expert_routes.py
git commit -m "feat(api): add official activity user endpoints and pin official expert in list"
```

---

### Task 8：task scheduler 自动开奖任务

**Files:**
- Modify: `backend/app/task_scheduler.py` (末尾加任务注册)
- Create: `backend/app/official_draw_task.py`

**Step 1：创建 `official_draw_task.py`**
```python
"""
官方活动自动开奖 task scheduler 任务
（保留 Celery 接口以便切换）
"""
import random
import logging
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app import models
from app.database import SessionLocal
from app.utils import get_utc_time

logger = logging.getLogger(__name__)


def run_auto_draws(db: Session):
    """
    定时检查需要自动开奖的活动（每 60 秒执行一次）。
    找 draw_mode=auto, is_drawn=False, draw_at <= now 的活动执行开奖。
    """
    now = get_utc_time()
    activities = db.execute(
        select(models.Activity).where(
            models.Activity.activity_type == "lottery",
            models.Activity.draw_mode == "auto",
            models.Activity.is_drawn == False,
            models.Activity.draw_at <= now,
            models.Activity.status == "open",
        )
    ).scalars().all()

    for activity in activities:
        try:
            _perform_draw_sync(db, activity)
            logger.info(f"Auto draw completed for activity {activity.id}")
        except Exception as e:
            logger.error(f"Auto draw failed for activity {activity.id}: {e}")
            db.rollback()


def _perform_draw_sync(db: Session, activity: models.Activity):
    """同步版本的开奖逻辑（task scheduler 使用同步 DB）"""
    from app.crud.notification import create_notification

    all_apps = db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending",
        )
    ).all()

    prize_count = activity.prize_count or 1
    selected = random.sample(all_apps, min(prize_count, len(all_apps)))
    selected_ids = {app.user_id for app, _ in selected}
    voucher_codes = activity.voucher_codes or []
    winners_data = []

    for i, (app, user) in enumerate(selected):
        app.status = "won"
        app.notified_at = get_utc_time()
        if activity.prize_type == "voucher_code" and i < len(voucher_codes):
            app.prize_index = i
        winners_data.append({"user_id": app.user_id, "name": user.name, "prize_index": app.prize_index})

        prize_desc = activity.prize_description or "奖品"
        voucher_info = f"\n您的优惠码：{voucher_codes[i]}" if app.prize_index is not None and i < len(voucher_codes) else ""
        create_notification(
            db=db, user_id=app.user_id,
            type="official_activity_won",
            title="🎉 恭喜中奖！",
            content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
            title_en="🎉 You won!",
            content_en=f"Activity '{activity.title_en or activity.title}' draw result: You won!{voucher_info}",
            related_id=str(activity.id),
            related_type="activity_id",
            auto_commit=False,
        )

    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"
    db.commit()


# ── Celery 接口（保留，便于切换）─────────────────────────
# 取消注释即可切换到 Celery
#
# from celery import shared_task
#
# @shared_task(name="official_draw.run_auto_draw")
# def celery_auto_draw(activity_id: int):
#     db = SessionLocal()
#     try:
#         from sqlalchemy import select
#         activity = db.execute(
#             select(models.Activity).where(models.Activity.id == activity_id)
#         ).scalar_one()
#         _perform_draw_sync(db, activity)
#     finally:
#         db.close()
```

**Step 2：在 task_scheduler.py 注册任务**

打开 `backend/app/task_scheduler.py`，找到 `init_scheduler()` 函数末尾（在 `scheduler.start()` 之前），加：

```python
# 官方活动自动开奖（每 60 秒检查一次）
from app.official_draw_task import run_auto_draws
scheduler.register_task(
    name="official_activity_auto_draw",
    func=with_db(run_auto_draws),
    interval_seconds=60,
    description="官方抽奖活动自动开奖",
    priority="normal",
)
```

**Step 3：Commit**
```bash
git add backend/app/official_draw_task.py backend/app/task_scheduler.py
git commit -m "feat(scheduler): add official activity auto draw task (with Celery interface)"
```

---

## Phase 5：Flutter

### Task 9：更新 Flutter TaskExpert 模型

**Files:**
- Modify: `link2ur/lib/data/models/task_expert.dart`

**Step 1：在 TaskExpert 类加字段**

找到现有字段列表，加入：
```dart
final bool isOfficial;
final String? officialBadge;
```

在 `fromJson` 工厂方法加：
```dart
isOfficial: json['is_official'] as bool? ?? false,
officialBadge: json['official_badge'] as String?,
```

在 `toJson` 加：
```dart
'is_official': isOfficial,
'official_badge': officialBadge,
```

在构造函数和 `copyWith` 加对应参数（保持现有 copyWith 风格）。

在 `props` 列表加 `isOfficial`, `officialBadge`。

**Step 2：Commit**
```bash
git add link2ur/lib/data/models/task_expert.dart
git commit -m "feat(flutter): add isOfficial fields to TaskExpert model"
```

---

### Task 10：更新 Flutter Activity 模型

**Files:**
- Modify: `link2ur/lib/data/models/activity.dart`

**Step 1：在 Activity 类加新字段**
```dart
final String activityType;        // 'standard' | 'lottery' | 'first_come'
final String? prizeType;          // 'points' | 'physical' | 'voucher_code' | 'in_person'
final String? prizeDescription;
final String? prizeDescriptionEn;
final int? prizeCount;
final String? drawMode;           // 'auto' | 'manual'
final DateTime? drawAt;
final DateTime? drawnAt;
final List<ActivityWinner>? winners;
final bool isDrawn;
final bool isOfficial;
final int? currentApplicants;

// Computed helpers
bool get isLottery => activityType == 'lottery';
bool get isFirstCome => activityType == 'first_come';
bool get isOfficialActivity => activityType != 'standard';
```

**Step 2：在同文件（或新建）加 ActivityWinner 类**
```dart
class ActivityWinner extends Equatable {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int? prizeIndex;

  const ActivityWinner({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.prizeIndex,
  });

  factory ActivityWinner.fromJson(Map<String, dynamic> json) => ActivityWinner(
    userId: json['user_id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    prizeIndex: json['prize_index'] as int?,
  );

  @override
  List<Object?> get props => [userId, name, avatarUrl, prizeIndex];
}
```

**Step 3：更新 fromJson / toJson / copyWith / props**（遵循文件现有风格）

**Step 4：Commit**
```bash
git add link2ur/lib/data/models/activity.dart
git commit -m "feat(flutter): add official activity fields to Activity model"
```

---

### Task 11：更新 ActivityBloc

**Files:**
- Modify: `link2ur/lib/features/activity/bloc/activity_bloc.dart`

**Step 1：加新事件**

在 events 部分加：
```dart
class ActivityApplyOfficial extends ActivityEvent {
  final int activityId;
  const ActivityApplyOfficial({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityCancelApplyOfficial extends ActivityEvent {
  final int activityId;
  const ActivityCancelApplyOfficial({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityLoadResult extends ActivityEvent {
  final int activityId;
  const ActivityLoadResult({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}
```

**Step 2：加新状态字段**

在 ActivityState 的 copyWith 可访问字段里加：
```dart
final OfficialActivityResult? officialResult;
final OfficialApplyStatus? officialApplyStatus;
// enum OfficialApplyStatus { applying, applied, full, error }
```

**Step 3：在 bloc 的 `on<>` 注册中加事件处理**
```dart
on<ActivityApplyOfficial>(_onApplyOfficial);
on<ActivityCancelApplyOfficial>(_onCancelApplyOfficial);
on<ActivityLoadResult>(_onLoadResult);
```

**Step 4：实现处理函数**
```dart
Future<void> _onApplyOfficial(
  ActivityApplyOfficial event,
  Emitter<ActivityState> emit,
) async {
  emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applying));
  try {
    await _activityRepository.applyOfficialActivity(event.activityId);
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applied));
  } catch (e) {
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.error));
  }
}
```

（`cancelApplyOfficial` 和 `loadResult` 类似，`loadResult` 把结果存入 `officialResult`）

**Step 5：在 ActivityRepository 加方法**

文件 `link2ur/lib/data/repositories/activity_repository.dart`：
```dart
Future<void> applyOfficialActivity(int activityId) async {
  await _apiService.post(
    ApiEndpoints.officialActivityApply(activityId),
  );
}

Future<void> cancelOfficialActivityApplication(int activityId) async {
  await _apiService.delete(
    ApiEndpoints.officialActivityApply(activityId),
  );
}

Future<OfficialActivityResult> getOfficialActivityResult(int activityId) async {
  final response = await _apiService.get(
    ApiEndpoints.officialActivityResult(activityId),
  );
  return OfficialActivityResult.fromJson(response.data);
}
```

**Step 6：在 `api_endpoints.dart` 加 endpoints**
```dart
static String officialActivityApply(int id) => '/api/official-activities/$id/apply';
static String officialActivityResult(int id) => '/api/official-activities/$id/result';
```

**Step 7：Commit**
```bash
git add link2ur/lib/features/activity/bloc/activity_bloc.dart \
        link2ur/lib/data/repositories/activity_repository.dart \
        link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat(flutter): add official activity BLoC events and repository methods"
```

---

### Task 12：Flutter UI — 官方徽章 + 活动详情动态渲染

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/task_expert_list_view.dart`
- Modify: `link2ur/lib/features/activity/views/activity_detail_view.dart`

**Step 1：达人列表加官方徽章**

在 `task_expert_list_view.dart` 中，找到渲染达人卡片的地方（搜索 `ExpertCard` 或类似组件），在卡片右上角叠加徽章：

```dart
if (expert.isOfficial)
  Positioned(
    top: 8,
    right: 8,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700), // 金色
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        expert.officialBadge ?? '官方',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ),
  ),
```

**Step 2：活动详情页加官方活动区块**

在 `activity_detail_view.dart` 底部操作区，根据 `activityType` 动态渲染：

```dart
Widget _buildBottomActionBar(BuildContext context, Activity activity) {
  if (activity.isOfficialActivity) {
    return _buildOfficialActionBar(context, activity);
  }
  // ... 现有逻辑
}

Widget _buildOfficialActionBar(BuildContext context, Activity activity) {
  final l10n = context.l10n;

  // 奖品区块
  final prizeSection = _buildPrizeSection(activity);

  if (activity.isLottery) {
    if (activity.isDrawn) {
      return Column(children: [
        prizeSection,
        _buildWinnersSection(activity),
        // 我的结果 banner
      ]);
    }
    return Column(children: [
      prizeSection,
      // 截止时间 + 当前报名人数
      Text('报名截止：${_formatDeadline(activity.drawAt)}'),
      Text('当前报名：${activity.currentApplicants ?? 0} 人'),
      ElevatedButton(
        onPressed: () => context.read<ActivityBloc>()
            .add(ActivityApplyOfficial(activityId: activity.id)),
        child: const Text('参与抽奖'),
      ),
    ]);
  }

  if (activity.isFirstCome) {
    final remaining = (activity.prizeCount ?? 0) - (activity.currentApplicants ?? 0);
    return Column(children: [
      prizeSection,
      Text('剩余名额：$remaining'),
      ElevatedButton(
        onPressed: remaining > 0
            ? () => context.read<ActivityBloc>()
                .add(ActivityApplyOfficial(activityId: activity.id))
            : null,
        child: Text(remaining > 0 ? '立即报名' : '已抢完'),
      ),
    ]);
  }

  return const SizedBox.shrink();
}

Widget _buildPrizeSection(Activity activity) {
  final prizeLabels = {
    'points': '🎯 积分奖励',
    'physical': '🎁 实物奖品',
    'voucher_code': '🎫 优惠券码',
    'in_person': '🍽️ 线下到场',
  };
  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9E6),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFFD700)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prizeLabels[activity.prizeType] ?? '奖品',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (activity.prizeDescription != null)
          Text(activity.prizeDescription!),
      ],
    ),
  );
}
```

**Step 3：Commit**
```bash
git add link2ur/lib/features/task_expert/views/task_expert_list_view.dart \
        link2ur/lib/features/activity/views/activity_detail_view.dart
git commit -m "feat(flutter): add official badge to expert list and official activity UI"
```

---

## Phase 6：iOS

### Task 13：更新 iOS 模型

**Files:**
- Modify: `ios/link2ur/link2ur/Models/TaskExpert.swift`
- Modify: `ios/link2ur/link2ur/Models/Activity.swift`

**Step 1：TaskExpert.swift 加字段**
```swift
// 在现有字段后加：
let isOfficial: Bool?
let officialBadge: String?
```

**Step 2：Activity.swift 加字段**
```swift
// 在现有字段后加：
let activityType: String?
let prizeType: String?
let prizeDescription: String?
let prizeDescriptionEn: String?
let prizeCount: Int?
let drawMode: String?
let drawAt: String?
let drawnAt: String?
let winners: [ActivityWinner]?
let isDrawn: Bool?
let isOfficial: Bool?
let currentApplicants: Int?

// Computed helpers
var isLottery: Bool { activityType == "lottery" }
var isFirstCome: Bool { activityType == "first_come" }
var isOfficialActivity: Bool { activityType == "lottery" || activityType == "first_come" }
```

**Step 3：在 Activity.swift 同文件加 ActivityWinner struct**
```swift
struct ActivityWinner: Codable, Identifiable {
    let userId: String
    let name: String
    let avatarUrl: String?
    let prizeIndex: Int?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case avatarUrl = "avatar_url"
        case prizeIndex = "prize_index"
    }
}
```

**Step 4：在 Activity.swift 加 OfficialActivityResult struct**
```swift
struct OfficialActivityResult: Codable {
    let isDrawn: Bool
    let drawnAt: String?
    let winners: [ActivityWinner]
    let myStatus: String?
    let myVoucherCode: String?

    enum CodingKeys: String, CodingKey {
        case isDrawn = "is_drawn"
        case drawnAt = "drawn_at"
        case winners
        case myStatus = "my_status"
        case myVoucherCode = "my_voucher_code"
    }
}
```

**Step 5：Commit**
```bash
git add ios/link2ur/link2ur/Models/TaskExpert.swift \
        ios/link2ur/link2ur/Models/Activity.swift
git commit -m "feat(ios): add official account and activity fields to models"
```

---

### Task 14：iOS APIService 扩展

**Files:**
- Create: `ios/link2ur/link2ur/Services/APIService+OfficialActivities.swift`

**Step 1：创建文件**
```swift
import Combine

extension APIService {

    func applyToOfficialActivity(activityId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(
            EmptyResponse.self,
            "/api/official-activities/\(activityId)/apply",
            method: "POST"
        )
    }

    func cancelOfficialActivityApplication(activityId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(
            EmptyResponse.self,
            "/api/official-activities/\(activityId)/apply",
            method: "DELETE"
        )
    }

    func getOfficialActivityResult(activityId: Int) -> AnyPublisher<OfficialActivityResult, APIError> {
        return request(
            OfficialActivityResult.self,
            "/api/official-activities/\(activityId)/result"
        )
    }
}
```

**Step 2：Commit**
```bash
git add ios/link2ur/link2ur/Services/APIService+OfficialActivities.swift
git commit -m "feat(ios): add APIService extension for official activities"
```

---

### Task 15：iOS ViewModel 更新

**Files:**
- Modify: `ios/link2ur/link2ur/ViewModels/ActivityViewModel.swift`

**Step 1：加新 Published 属性**
```swift
enum OfficialApplyStatus {
    case idle, applying, applied, full, error(String)
}

@Published var officialApplyStatus: OfficialApplyStatus = .idle
@Published var myActivityResult: OfficialActivityResult?
```

**Step 2：加新方法**
```swift
func applyToOfficialActivity(activityId: Int) {
    officialApplyStatus = .applying
    apiService.applyToOfficialActivity(activityId: activityId)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    if case .serverError(_, let msg, _) = error, msg.contains("已满") {
                        self?.officialApplyStatus = .full
                    } else {
                        self?.officialApplyStatus = .error(error.userFriendlyMessage)
                    }
                }
            },
            receiveValue: { [weak self] _ in
                self?.officialApplyStatus = .applied
            }
        )
        .store(in: &cancellables)
}

func loadOfficialActivityResult(activityId: Int) {
    apiService.getOfficialActivityResult(activityId: activityId)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] result in
                self?.myActivityResult = result
            }
        )
        .store(in: &cancellables)
}

func cancelOfficialApplication(activityId: Int, completion: @escaping (Bool) -> Void) {
    apiService.cancelOfficialActivityApplication(activityId: activityId)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { result in
                completion(result == .finished)
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
}
```

**Step 3：Commit**
```bash
git add ios/link2ur/link2ur/ViewModels/ActivityViewModel.swift
git commit -m "feat(ios): add official activity methods to ActivityViewModel"
```

---

### Task 16：iOS View 更新

**Files:**
- Modify: `ios/link2ur/link2ur/Views/TaskExpert/TaskExpertListView.swift`
- Modify: `ios/link2ur/link2ur/Views/Activity/ActivityDetailView.swift`
- Create: `ios/link2ur/link2ur/Views/Components/OfficialBadgeView.swift`
- Create: `ios/link2ur/link2ur/Views/Components/ActivityPrizeSection.swift`
- Create: `ios/link2ur/link2ur/Views/Components/WinnersListView.swift`

**Step 1：创建 OfficialBadgeView.swift**
```swift
import SwiftUI

struct OfficialBadgeView: View {
    let badge: String

    init(badge: String = "官方") {
        self.badge = badge
    }

    var body: some View {
        Text(badge)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.black.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: "#FFD700"))
            .cornerRadius(4)
    }
}
```

**Step 2：创建 ActivityPrizeSection.swift**
```swift
import SwiftUI

struct ActivityPrizeSection: View {
    let activity: Activity

    private var prizeLabel: String {
        switch activity.prizeType {
        case "points": return "🎯 积分奖励"
        case "physical": return "🎁 实物奖品"
        case "voucher_code": return "🎫 优惠券码"
        case "in_person": return "🍽️ 线下到场"
        default: return "🎁 奖品"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prizeLabel)
                .font(.system(size: 14, weight: .bold))
            if let desc = activity.prizeDescription {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "#FFF9E6"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#FFD700"), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
```

**Step 3：创建 WinnersListView.swift**
```swift
import SwiftUI

struct WinnersListView: View {
    let winners: [ActivityWinner]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🏆 中奖名单")
                .font(.system(size: 14, weight: .bold))
            ForEach(winners) { winner in
                HStack {
                    AsyncImageView(url: winner.avatarUrl, size: 28)
                    Text(winner.name)
                        .font(.system(size: 13))
                    Spacer()
                }
            }
        }
    }
}
```

**Step 4：在 TaskExpertListView.swift 加官方徽章**

找到渲染 expert 卡片的地方（搜索 `expert.name` 或卡片组件），在卡片右上角叠加徽章：
```swift
if expert.isOfficial == true {
    OfficialBadgeView(badge: expert.officialBadge ?? "官方")
}
```

**Step 5：在 ActivityDetailView.swift 加官方活动 UI**

找到底部 action bar 的渲染位置，加条件判断：
```swift
if activity.isOfficialActivity {
    officialActivityBottomBar(activity: activity)
} else {
    // 现有逻辑
}
```

实现 `officialActivityBottomBar`（与 Flutter 端逻辑对称）：
```swift
@ViewBuilder
func officialActivityBottomBar(activity: Activity) -> some View {
    VStack(spacing: 12) {
        ActivityPrizeSection(activity: activity)

        if activity.isLottery {
            if activity.isDrawn == true {
                WinnersListView(winners: activity.winners ?? [])
                // 我的结果
                if let result = viewModel.myActivityResult {
                    myResultBanner(result: result)
                }
            } else {
                if let drawAt = activity.drawAt {
                    Text("报名截止：\(drawAt)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Text("当前报名：\(activity.currentApplicants ?? 0) 人")
                    .font(.caption).foregroundColor(.secondary)
                applyButton(title: "参与抽奖", activityId: activity.id)
            }
        } else if activity.isFirstCome {
            let remaining = (activity.prizeCount ?? 0) - (activity.currentApplicants ?? 0)
            Text("剩余名额：\(remaining)")
                .font(.caption).foregroundColor(.secondary)
            applyButton(title: remaining > 0 ? "立即报名" : "已抢完",
                       activityId: activity.id,
                       disabled: remaining <= 0)
        }
    }
    .padding()
}

@ViewBuilder
func applyButton(title: String, activityId: Int, disabled: Bool = false) -> some View {
    Button(action: { viewModel.applyToOfficialActivity(activityId: activityId) }) {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(disabled ? Color.gray : AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppCornerRadius.medium)
    }
    .disabled(disabled)
}
```

**Step 6：在 Localizable.strings (en/zh/zh_Hant) 加本地化字符串**

`Localizable.strings (Chinese (Simplified))`：
```
"official" = "官方";
"activity_type_lottery" = "抽奖活动";
"activity_type_first_come" = "限量抢位";
"prize_type_points" = "积分奖励";
"prize_type_physical" = "实物奖品";
"prize_type_voucher" = "优惠券码";
"prize_type_in_person" = "线下到场";
"draw_pending" = "等待开奖";
"draw_won" = "恭喜中奖！";
"draw_lost" = "未中奖，下次加油";
```

`Localizable.strings (English)`：
```
"official" = "Official";
"activity_type_lottery" = "Lottery";
"activity_type_first_come" = "First Come First Served";
"prize_type_points" = "Points Reward";
"prize_type_physical" = "Physical Prize";
"prize_type_voucher" = "Voucher Code";
"prize_type_in_person" = "In-Person Event";
"draw_pending" = "Awaiting Draw";
"draw_won" = "Congratulations, You Won!";
"draw_lost" = "Better luck next time!";
```

**Step 7：Commit**
```bash
git add ios/link2ur/link2ur/Views/
git commit -m "feat(ios): add official badge, prize section, winners list, and activity detail UI"
```

---

## 完成检查清单

- [ ] 所有 ALTER TABLE 在 Railway PostgreSQL 执行成功
- [ ] 官方账号可通过 admin endpoint 设置
- [ ] 官方账号在达人列表置顶，有徽章
- [ ] 官方活动（抽奖/抢位）可由管理员创建
- [ ] 用户可报名/取消报名
- [ ] 手动开奖正常工作，通知发送成功
- [ ] 自动开奖 task scheduler 每 60 秒触发（verify: `scheduler.get_task_status('official_activity_auto_draw')`）
- [ ] Flutter: 活动详情页根据 activityType 正确渲染
- [ ] iOS: 活动详情页根据 activityType 正确渲染
- [ ] 不在范围内：admin panel UI、推送通知、分享功能
