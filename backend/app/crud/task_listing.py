"""任务列表与计数查询（公开任务筛选、排序、分页），独立模块便于维护与测试。"""
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, case, func, not_, or_
from sqlalchemy.orm import Session, selectinload

from app.models import Task
from app.utils.time_utils import get_utc_time


def list_tasks(
    db: Session,
    skip: int = 0,
    limit: int = 20,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    sort_by: str = "latest",
):
    now_utc = get_utc_time()
    query = (
        db.query(Task)
        .options(selectinload(Task.poster))
        .filter(
            and_(
                Task.status == "open",
                or_(
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc,
                    ),
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc.replace(tzinfo=None),
                    ),
                ),
            )
        )
    )

    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type.strip())

    if location and location.strip():
        loc = location.strip()
        if loc.lower() == "other":
            from app.utils.city_filter_utils import build_other_exclusion_filter

            exclusion_expr = build_other_exclusion_filter(Task.location)
            if exclusion_expr is not None:
                query = query.filter(not_(exclusion_expr))
        elif loc.lower() == "online":
            query = query.filter(Task.location.ilike("%online%"))
        else:
            from app.utils.city_filter_utils import build_city_location_filter

            city_expr = build_city_location_filter(Task.location, loc)
            if city_expr is not None:
                query = query.filter(city_expr)

    if keyword and keyword.strip():
        keyword_clean = keyword.strip()[:100]
        keyword_escaped = keyword_clean.replace("%", r"\%").replace(
            "_", r"\_"
        )
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                func.similarity(Task.title_zh, keyword_clean) > 0.2,
                func.similarity(Task.title_en, keyword_clean) > 0.2,
                func.similarity(Task.description_zh, keyword_clean) > 0.2,
                func.similarity(Task.description_en, keyword_clean) > 0.2,
                func.similarity(Task.task_type, keyword_clean) > 0.2,
                func.similarity(Task.location, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_escaped}%"),
                Task.description.ilike(f"%{keyword_escaped}%"),
                Task.title_zh.ilike(f"%{keyword_escaped}%"),
                Task.title_en.ilike(f"%{keyword_escaped}%"),
                Task.description_zh.ilike(f"%{keyword_escaped}%"),
                Task.description_en.ilike(f"%{keyword_escaped}%"),
            )
        )

    if sort_by == "latest":
        recent_24h = now_utc - timedelta(hours=24)
        sort_weight = case(
            (Task.created_at >= recent_24h, 2),
            else_=1,
        )
        query = query.order_by(
            sort_weight.desc(),
            Task.created_at.desc(),
        )
    elif sort_by == "reward_asc":
        query = query.order_by(Task.base_reward.asc())
    elif sort_by == "reward_desc":
        query = query.order_by(Task.base_reward.desc())
    elif sort_by == "deadline_asc":
        query = query.order_by(Task.deadline.asc())
    elif sort_by == "deadline_desc":
        query = query.order_by(Task.deadline.desc())
    else:
        recent_24h = now_utc - timedelta(hours=24)
        sort_weight = case(
            (Task.created_at >= recent_24h, 2),
            else_=1,
        )
        query = query.order_by(sort_weight.desc(), Task.created_at.desc())

    tasks = query.offset(skip).limit(limit).all()

    recent_24h = now_utc - timedelta(hours=24)
    for task in tasks:
        if task.poster:
            task.poster_timezone = (
                task.poster.timezone if task.poster.timezone else "UTC"
            )
            task_hours_old = (
                (now_utc - task.created_at).total_seconds() / 3600
                if hasattr((now_utc - task.created_at), "total_seconds")
                else 999
            )
            user_days_old = (
                (now_utc - task.poster.created_at).days
                if hasattr(
                    (now_utc - task.poster.created_at), "days"
                )
                else 999
            )
            task.is_new_task = task_hours_old <= 24
            task.is_new_user_task = (
                task_hours_old <= 24 and user_days_old <= 7
            )
        else:
            task.poster_timezone = "UTC"
            task.is_new_task = False
            task.is_new_user_task = False

    tasks.sort(
        key=lambda t: (
            -1
            if (hasattr(t, "is_new_user_task") and t.is_new_user_task)
            else 0,
            -1 if (hasattr(t, "is_new_task") and t.is_new_task) else 0,
            t.created_at
            if t.created_at
            else datetime.min.replace(tzinfo=timezone.utc),
        ),
        reverse=True,
    )
    return tasks


def count_tasks(
    db: Session,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
):
    """计算符合条件的任务总数（与 list_tasks 筛选条件一致）。"""
    now_utc = get_utc_time()
    query = (
        db.query(Task)
        .filter(
            and_(
                Task.status == "open",
                or_(
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc,
                    ),
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc.replace(tzinfo=None),
                    ),
                ),
            )
        )
    )

    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type.strip())

    if location and location.strip():
        loc = location.strip()
        if loc.lower() == "other":
            from app.utils.city_filter_utils import build_other_exclusion_filter

            exclusion_expr = build_other_exclusion_filter(Task.location)
            if exclusion_expr is not None:
                query = query.filter(not_(exclusion_expr))
        elif loc.lower() == "online":
            query = query.filter(Task.location.ilike("%online%"))
        else:
            from app.utils.city_filter_utils import build_city_location_filter

            city_expr = build_city_location_filter(Task.location, loc)
            if city_expr is not None:
                query = query.filter(city_expr)

    if keyword and keyword.strip():
        keyword_clean = keyword.strip()[:100]
        keyword_escaped = keyword_clean.replace("%", r"\%").replace(
            "_", r"\_"
        )
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                func.similarity(Task.title_zh, keyword_clean) > 0.2,
                func.similarity(Task.title_en, keyword_clean) > 0.2,
                func.similarity(Task.description_zh, keyword_clean) > 0.2,
                func.similarity(Task.description_en, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_escaped}%"),
                Task.description.ilike(f"%{keyword_escaped}%"),
                Task.title_zh.ilike(f"%{keyword_escaped}%"),
                Task.title_en.ilike(f"%{keyword_escaped}%"),
                Task.description_zh.ilike(f"%{keyword_escaped}%"),
                Task.description_en.ilike(f"%{keyword_escaped}%"),
            )
        )

    return query.count()
