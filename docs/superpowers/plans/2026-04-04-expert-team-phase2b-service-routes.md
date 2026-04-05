# 达人团队体系 Phase 2b — 新服务路由

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建达人团队服务 CRUD 路由 `/api/experts/{id}/services/*`，使用新的 `owner_type`/`owner_id` 列，Owner/Admin 可自由创建编辑服务（无需审核）。

**Architecture:** 新建 `expert_service_routes.py` 路由文件，复用现有 `TaskExpertService` 模型（加了 `owner_type`/`owner_id`）和 `schemas.py` 中的服务 schemas。路由使用 Phase 1a 的权限检查函数 `_get_member_or_403`。旧路由 `task_expert_routes.py` 不动。

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy (async), Pydantic v2

**依赖:** Phase 1a（experts + expert_members 表）、Phase 2a（owner_type/owner_id 列）

---

## File Structure

### New Files
- `backend/app/expert_service_routes.py` — 达人团队服务 CRUD 路由

### Modified Files
- `backend/app/main.py` — 注册新路由
- `link2ur/lib/core/constants/api_endpoints.dart` — 新增端点常量

---

## Task 1: 达人团队服务路由

**Files:**
- Create: `backend/app/expert_service_routes.py`

- [ ] **Step 1: 创建路由文件**

路由前缀：`/api/experts/{expert_id}/services`

端点列表：
1. `GET /` — 获取达人团队的服务列表（公开）
2. `POST /` — 创建服务（Owner/Admin，无需审核）
3. `GET /{service_id}` — 获取服务详情（公开）
4. `PUT /{service_id}` — 更新服务（Owner/Admin）
5. `DELETE /{service_id}` — 删除服务（Owner/Admin）

关键实现细节：
- 创建服务时设置 `owner_type='expert'`、`owner_id=expert_id`，同时也设置旧列 `expert_id`（双写兼容）
- 查询服务优先用新列 `owner_type='expert' AND owner_id=expert_id`
- 权限检查：复用 `expert_routes.py` 中的 `_get_member_or_403` 和 `_get_expert_or_404`
- 服务状态直接设为 'active'（无需审核，spec 决策 #26）
- 复用现有 `schemas.TaskExpertServiceCreate` 和 `schemas.TaskExpertServiceOut`

```python
"""达人团队服务管理路由"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.deps import get_async_db_dependency
from app.async_routers import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
)
from app.models_expert import Expert, ExpertMember
from app.expert_routes import _get_expert_or_404, _get_member_or_403
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_service_router = APIRouter(
    prefix="/api/experts/{expert_id}/services",
    tags=["expert-services"],
)


@expert_service_router.get("", response_model=List[dict])
async def list_expert_services(
    expert_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
):
    """获取达人团队的服务列表（公开）"""
    await _get_expert_or_404(db, expert_id)

    query = select(models.TaskExpertService).where(
        and_(
            models.TaskExpertService.owner_type == "expert",
            models.TaskExpertService.owner_id == expert_id,
        )
    )
    if status_filter:
        query = query.where(models.TaskExpertService.status == status_filter)
    else:
        # 公开访问默认只显示 active
        if not current_user:
            query = query.where(models.TaskExpertService.status == "active")

    query = query.order_by(
        models.TaskExpertService.display_order.asc(),
        models.TaskExpertService.created_at.desc(),
    ).offset(offset).limit(limit)

    result = await db.execute(query)
    services = result.scalars().all()

    return [
        {
            "id": s.id,
            "service_name": s.service_name,
            "service_name_en": s.service_name_en,
            "service_name_zh": s.service_name_zh,
            "description": s.description,
            "description_en": s.description_en,
            "description_zh": s.description_zh,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency,
            "pricing_type": s.pricing_type,
            "location_type": s.location_type,
            "location": s.location,
            "category": s.category,
            "images": s.images,
            "skills": s.skills,
            "status": s.status,
            "has_time_slots": s.has_time_slots,
            "view_count": s.view_count or 0,
            "application_count": s.application_count or 0,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "owner_type": s.owner_type,
            "owner_id": s.owner_id,
        }
        for s in services
    ]


@expert_service_router.post("", status_code=201)
async def create_expert_service(
    expert_id: str,
    body: schemas.TaskExpertServiceCreate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """创建达人服务（Owner/Admin，无需审核）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    service = models.TaskExpertService(
        # 新列
        owner_type="expert",
        owner_id=expert_id,
        # 旧列（双写兼容）
        expert_id=None,  # 旧列指向 task_experts.id，新模型下不再使用
        service_type="expert",
        user_id=None,
        # 业务字段
        service_name=body.service_name,
        service_name_en=getattr(body, 'service_name_en', None),
        service_name_zh=getattr(body, 'service_name_zh', None),
        description=body.description,
        description_en=getattr(body, 'description_en', None),
        description_zh=getattr(body, 'description_zh', None),
        category=getattr(body, 'category', None),
        images=getattr(body, 'images', None),
        base_price=body.base_price,
        currency=getattr(body, 'currency', 'GBP'),
        pricing_type=getattr(body, 'pricing_type', 'fixed'),
        location_type=getattr(body, 'location_type', 'online'),
        location=getattr(body, 'location', None),
        skills=getattr(body, 'skills', None),
        status="active",  # 达人服务无需审核
        has_time_slots=getattr(body, 'has_time_slots', False),
        time_slot_duration_minutes=getattr(body, 'time_slot_duration_minutes', None),
        participants_per_slot=getattr(body, 'participants_per_slot', None),
        weekly_time_slot_config=getattr(body, 'weekly_time_slot_config', None),
    )
    db.add(service)

    # 更新达人统计
    expert.total_services = (expert.total_services or 0) + 1
    expert.updated_at = get_utc_time()

    await db.commit()
    await db.refresh(service)
    return {"id": service.id, "status": service.status}


@expert_service_router.get("/{service_id}")
async def get_expert_service_detail(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取服务详情（公开）"""
    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    # 增加浏览量
    service.view_count = (service.view_count or 0) + 1
    await db.commit()

    return {
        "id": service.id,
        "service_name": service.service_name,
        "service_name_en": service.service_name_en,
        "service_name_zh": service.service_name_zh,
        "description": service.description,
        "description_en": service.description_en,
        "description_zh": service.description_zh,
        "base_price": float(service.base_price) if service.base_price else 0,
        "currency": service.currency,
        "pricing_type": service.pricing_type,
        "location_type": service.location_type,
        "location": service.location,
        "latitude": float(service.latitude) if service.latitude else None,
        "longitude": float(service.longitude) if service.longitude else None,
        "category": service.category,
        "images": service.images,
        "skills": service.skills,
        "status": service.status,
        "display_order": service.display_order,
        "has_time_slots": service.has_time_slots,
        "time_slot_duration_minutes": service.time_slot_duration_minutes,
        "participants_per_slot": service.participants_per_slot,
        "weekly_time_slot_config": service.weekly_time_slot_config,
        "view_count": service.view_count or 0,
        "application_count": service.application_count or 0,
        "created_at": service.created_at.isoformat() if service.created_at else None,
        "updated_at": service.updated_at.isoformat() if service.updated_at else None,
        "owner_type": service.owner_type,
        "owner_id": service.owner_id,
    }


@expert_service_router.put("/{service_id}")
async def update_expert_service(
    expert_id: str,
    service_id: int,
    body: schemas.TaskExpertServiceUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人服务（Owner/Admin）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    # 更新提供的字段
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(service, field):
            setattr(service, field, value)
    service.updated_at = get_utc_time()

    await db.commit()
    return {"id": service.id, "status": service.status}


@expert_service_router.delete("/{service_id}")
async def delete_expert_service(
    expert_id: str,
    service_id: int,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """删除达人服务（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(models.TaskExpertService).where(
            and_(
                models.TaskExpertService.id == service_id,
                models.TaskExpertService.owner_type == "expert",
                models.TaskExpertService.owner_id == expert_id,
            )
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    await db.delete(service)
    expert.total_services = max((expert.total_services or 1) - 1, 0)
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"detail": "服务已删除"}
```

- [ ] **Step 2: 注册路由到 main.py**

在 `backend/app/main.py` 中，找到 `expert_router` 注册的位置，追加：

```python
from app.expert_service_routes import expert_service_router
app.include_router(expert_service_router)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/expert_service_routes.py backend/app/main.py
git commit -m "feat: add expert team service CRUD routes (/api/experts/{id}/services)"
```

---

## Task 2: Flutter 端点常量

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: 添加达人服务端点**

```dart
// Expert Team Services
static String expertTeamServices(String expertId) => '/api/experts/$expertId/services';
static String expertTeamServiceById(String expertId, int serviceId) =>
    '/api/experts/$expertId/services/$serviceId';
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add expert team service endpoint constants"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** 服务 CRUD 5 端点 ✅, Owner/Admin 权限 ✅, 无需审核 ✅, 双写兼容 ✅
- [x] **Placeholder scan:** 无 TBD
- [x] **Type consistency:** expert_service_router 命名一致
- [x] **Not in scope:** 时间段管理（旧路由仍可用）、服务申请/咨询（旧路由仍可用）、Flutter 页面适配（Phase 2c）
