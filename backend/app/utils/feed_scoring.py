"""
Feed 内容评分与个性化加权（共享给 discovery_routes / service_browse_routes 等）

包含：
- 城市变体（中英文互查）
- 热度分（互动 + 时间衰减）
- 偏好/同城/兴趣加权
- 用户个性化上下文加载
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models


# ==================== 城市变体 ====================

CITY_EN_TO_ZH = {
    'london': '伦敦', 'edinburgh': '爱丁堡', 'manchester': '曼彻斯特',
    'birmingham': '伯明翰', 'glasgow': '格拉斯哥', 'bristol': '布里斯托',
    'sheffield': '谢菲尔德', 'leeds': '利兹', 'nottingham': '诺丁汉',
    'newcastle': '纽卡斯尔', 'southampton': '南安普顿', 'liverpool': '利物浦',
    'cardiff': '卡迪夫', 'coventry': '考文垂', 'leicester': '莱斯特',
    'york': '约克', 'aberdeen': '阿伯丁', 'bath': '巴斯',
    'cambridge': '剑桥', 'oxford': '牛津', 'brighton': '布莱顿',
    'reading': '雷丁', 'belfast': '贝尔法斯特',
}
CITY_ZH_TO_EN = {v: k for k, v in CITY_EN_TO_ZH.items()}


def get_city_variants(city: Optional[str]) -> set:
    """返回城市名的中英文变体（小写），用于同城匹配。
    与 Flutter 端 DiscoverBloc._getCityVariants 保持一致。"""
    if not city:
        return set()
    cleaned = city.strip()
    lower = cleaned.lower()
    variants = {lower}
    if lower in CITY_EN_TO_ZH:
        variants.add(CITY_EN_TO_ZH[lower])
    if cleaned in CITY_ZH_TO_EN:
        variants.add(CITY_ZH_TO_EN[cleaned])
    return variants


# ==================== 热度分 ====================

def compute_score(item: dict) -> float:
    """计算内容热度分数（时间衰减 + 互动加权）

    - 互动分 = 点赞*3 + 评论*5 + 浏览*0.1 + 评分*2 + 赞成票*3
    - 时间衰减: score / (age_hours + 2) ^ 1.2
    - 保底 1.0
    """
    likes = item.get("like_count") or 0
    comments = item.get("comment_count") or 0
    views = item.get("view_count") or 0
    rating = item.get("rating") or 0
    upvotes = item.get("upvote_count") or 0

    engagement = likes * 3 + comments * 5 + views * 0.1 + rating * 2 + upvotes * 3

    created_str = item.get("created_at")
    if created_str:
        try:
            created = datetime.fromisoformat(created_str)
            if created.tzinfo is None:
                created = created.replace(tzinfo=timezone.utc)
            age_hours = (datetime.now(timezone.utc) - created).total_seconds() / 3600
        except (ValueError, TypeError):
            age_hours = 999
    else:
        age_hours = 999

    return max(engagement, 1.0) / (age_hours + 2) ** 1.2


def compute_score_with_prefs(item: dict, user_prefs: set,
                             city_variants: set = None,
                             user_interest_types: set = None) -> float:
    """热度分 + 偏好(×1.5) + 同城(×1.3) + 历史兴趣(×1.4)；最高 ≈ 2.73x"""
    base_score = compute_score(item)

    multiplier = 1.0
    ft = item.get("feed_type", "")
    extra = item.get("extra_data") or {}

    # 偏好加分
    if user_prefs:
        pref_matched = False
        if ft == "forum_post":
            cat_zh = extra.get("category_name_zh", "")
            cat_en = extra.get("category_name_en", "")
            for pref in user_prefs:
                pl = pref.lower()
                if pl in (cat_zh or "").lower() or pl in (cat_en or "").lower():
                    pref_matched = True
                    break
        elif ft == "activity":
            task_type = (extra.get("task_type") or "").lower()
            if task_type:
                for pref in user_prefs:
                    if pref.lower() == task_type or pref.lower() in task_type:
                        pref_matched = True
                        break
        elif ft == "service":
            category = (extra.get("category") or "").lower()
            if category:
                for pref in user_prefs:
                    if pref.lower() == category or pref.lower() in category:
                        pref_matched = True
                        break
            if not pref_matched:
                title = (item.get("title") or "").lower()
                desc = (item.get("description") or "").lower()
                for pref in user_prefs:
                    if pref.lower() in title or pref.lower() in desc:
                        pref_matched = True
                        break
        elif ft == "product":
            title = (item.get("title") or "").lower()
            desc = (item.get("description") or "").lower()
            for pref in user_prefs:
                if pref.lower() in title or pref.lower() in desc:
                    pref_matched = True
                    break
        elif ft == "expert":
            category = (extra.get("category") or "").lower()
            if category:
                for pref in user_prefs:
                    if pref.lower() == category or pref.lower() in category:
                        pref_matched = True
                        break
            if not pref_matched:
                skills = extra.get("featured_skills") or []
                skills_en = extra.get("featured_skills_en") or []
                blob = " ".join(s for s in (skills + skills_en) if s).lower()
                if blob:
                    for pref in user_prefs:
                        if pref.lower() in blob:
                            pref_matched = True
                            break
            if pref_matched:
                extra["reason_code"] = extra.get("reason_code") or "category_match"
        if pref_matched:
            multiplier *= 1.5

    # 同城加分
    if city_variants:
        city_matched = False
        if ft == "activity":
            activity_info = item.get("activity_info") or {}
            loc = activity_info.get("location") or ""
            city_matched = bool(loc) and any(v in loc.lower() for v in city_variants)
        elif ft == "expert":
            loc = extra.get("location") or ""
            city_matched = bool(loc) and any(v in loc.lower() for v in city_variants)
        elif ft == "service":
            loc = extra.get("location") or ""
            if loc:
                city_matched = any(v in loc.lower() for v in city_variants)
            else:
                text = ((item.get("title") or "") + " " + (item.get("description") or "")).lower()
                city_matched = any(v in text for v in city_variants)
        elif ft == "product":
            text = ((item.get("title") or "") + " " + (item.get("description") or "")).lower()
            city_matched = any(v in text for v in city_variants)

        if city_matched:
            multiplier *= 1.3
            extra["reason_code"] = extra.get("reason_code") or "same_city"

    # 历史兴趣加分
    if user_interest_types:
        interest_matched = False
        if ft == "activity":
            task_type = (extra.get("task_type") or "").lower()
            if task_type and task_type in user_interest_types:
                interest_matched = True
        elif ft == "service":
            category = (extra.get("category") or "").lower()
            if category and category in user_interest_types:
                interest_matched = True
        elif ft == "expert":
            category = (extra.get("category") or "").lower()
            if category and category in user_interest_types:
                interest_matched = True
        if interest_matched:
            multiplier *= 1.4
            if ft == "expert":
                extra["reason_code"] = extra.get("reason_code") or "category_match"

    return base_score * multiplier


def compute_task_score(item: dict, user_prefs: set = None,
                       city_variants: set = None,
                       user_interest_types: set = None) -> float:
    """任务的个性化排序分数

    综合分 = (推荐分 * 0.6 + 时效分 * 0.2 + 热度分 * 0.2) * 偏好/同城/兴趣乘数
    """
    extra = item.get("extra_data") or {}
    match_score = extra.get("match_score") or 0.0

    created_str = item.get("created_at")
    if created_str:
        try:
            created = datetime.fromisoformat(created_str)
            if created.tzinfo is None:
                created = created.replace(tzinfo=timezone.utc)
            age_hours = (datetime.now(timezone.utc) - created).total_seconds() / 3600
            recency_score = 1.0 / (1.0 + age_hours / 24.0)
        except (ValueError, TypeError):
            recency_score = 0.0
    else:
        recency_score = 0.0

    app_count = extra.get("application_count") or 0
    views = item.get("view_count") or 0
    popularity_score = min(1.0, (app_count * 0.15 + views * 0.005))

    base_score = match_score * 0.6 + recency_score * 0.2 + popularity_score * 0.2

    multiplier = 1.0
    task_type = (extra.get("task_type") or "").lower()

    if user_prefs and task_type:
        for pref in user_prefs:
            pl = pref.lower()
            if pl == task_type or pl in task_type:
                multiplier *= 1.5
                break

    if city_variants:
        loc = (extra.get("location") or "").lower()
        if loc and any(v in loc for v in city_variants):
            multiplier *= 1.3
            extra["reason_code"] = extra.get("reason_code") or "same_city"

    if user_interest_types and task_type and task_type in user_interest_types:
        multiplier *= 1.4

    return base_score * multiplier


# ==================== 用户个性化上下文加载 ====================

async def load_user_personalization_context(
    db: AsyncSession,
    current_user,
    explicit_city: Optional[str] = None,
) -> dict:
    """加载用户的偏好类别 / 城市 / 历史兴趣类型

    每个查询用 SAVEPOINT 隔离，单个失败不影响其他。

    Args:
        db: AsyncSession
        current_user: 当前登录用户（可为 None）
        explicit_city: 前端显式传入的 city（GPS 反向编码），优先级高于 residence_city

    Returns:
        {
            "user_prefs": list[str] — 偏好类别 + task_types 合集
            "user_city": Optional[str] — 用于显示
            "city_variants": set — 中英文小写变体
            "user_interest_types": set — 历史申请/参加过的类型（小写）
        }
    """
    user_prefs: list = []
    user_city = explicit_city
    user_interest_types: set = set()

    if current_user:
        if not user_city and getattr(current_user, "residence_city", None):
            user_city = current_user.residence_city

        # 偏好类别
        try:
            async with db.begin_nested():
                pref_result = await db.execute(
                    select(models.UserProfilePreference.preferred_categories,
                           models.UserProfilePreference.task_types)
                    .where(models.UserProfilePreference.user_id == current_user.id)
                )
                pref_row = pref_result.first()
                if pref_row:
                    cats = pref_row.preferred_categories or []
                    types = pref_row.task_types or []
                    user_prefs = list(set(cats + types))
        except Exception:
            pass

        # 历史申请的任务类型
        try:
            async with db.begin_nested():
                applied_types_result = await db.execute(
                    select(models.Task.task_type)
                    .join(models.TaskApplication, models.TaskApplication.task_id == models.Task.id)
                    .where(models.TaskApplication.applicant_id == current_user.id)
                    .group_by(models.Task.task_type)
                    .limit(20)
                )
                user_interest_types.update(r[0] for r in applied_types_result.all() if r[0])
        except Exception:
            pass

        # 历史参加的活动类型
        try:
            async with db.begin_nested():
                attended_types_result = await db.execute(
                    select(models.Activity.task_type)
                    .join(models.OfficialActivityApplication,
                          models.OfficialActivityApplication.activity_id == models.Activity.id)
                    .where(models.OfficialActivityApplication.user_id == current_user.id)
                    .group_by(models.Activity.task_type)
                    .limit(20)
                )
                user_interest_types.update(r[0] for r in attended_types_result.all() if r[0])
        except Exception:
            pass

    return {
        "user_prefs": user_prefs,
        "user_city": user_city,
        "city_variants": get_city_variants(user_city),
        "user_interest_types": {t.lower() for t in user_interest_types if t},
    }
