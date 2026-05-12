# Recommend Helpers by Intent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 AI 加新工具 `recommend_helpers_by_intent`,让 AI 在用户隐式表达需求时(先文本确认 → 调工具)返回候选人卡片,用户点卡跳 profile,无直接 CTA。

**Architecture:** 后端新模块 `helper_recommendation.py` 实现两池查询 + 评分 + 合并,在 `ai_tools.py` 注册新工具。`ai_agent.py` 的 `_DEFAULT_SYSTEM_PROMPT` 加触发规则段。Flutter 端在 `task_result_cards.dart` 加 `helpers` 渲染分支 + 内部 `_HelperCard` widget,`unified_chat_view.dart` 的 `hasTaskCards` const list 加 `'helpers'`。

**Tech Stack:** Python (FastAPI + SQLAlchemy async + Pydantic), PostgreSQL (JSONB), pytest + AsyncMock, Flutter (BLoC) + flutter_test。

**Spec reference:** `docs/superpowers/specs/2026-05-12-recommend-helpers-by-intent-design.md`

**Branch policy:** solo 项目,直接提交到 `main`,不开 feature branch,每个 task 完成后单独 commit。

---

## File Structure

| 路径 | 操作 | 责任 |
|---|---|---|
| `backend/app/services/helper_recommendation.py` | **新建** | 两池查询 + 评分 + 合并 + match_reason + city 归一化的核心算法,纯函数为主便于测试 |
| `backend/app/services/ai_tools.py` | **修改** | 注册新工具 `recommend_helpers_by_intent`,handler 调上面的模块 |
| `backend/app/services/ai_agent.py` | **修改** | `_DEFAULT_SYSTEM_PROMPT` 加职责 #20 + 触发规则段 |
| `backend/tests/test_helper_recommendation.py` | **新建** | 纯函数 + 主 recommend_helpers 的单元测试 (mock DB) |
| `link2ur/lib/features/ai_chat/widgets/task_result_cards.dart` | **修改** | 加 `helpers` 渲染分支 + 内部 `_HelperCard` widget |
| `link2ur/lib/features/ai_chat/views/unified_chat_view.dart` | **修改** | `hasTaskCards` const list 加 `'helpers'` (1 行) |
| `link2ur/test/features/ai_chat/widgets/helper_card_test.dart` | **新建** | HelperCard widget 测试 (3 种 match_reason 渲染 + 点击跳转) |
| `backend/docs/ai-agent.md` | **修改** | 工具数 37→38,加新工具简介 |

---

## Task 1: 创建 helper_recommendation 模块 + 城市归一化

**Files:**
- Create: `backend/app/services/helper_recommendation.py`
- Create: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写城市归一化的失败测试**

`backend/tests/test_helper_recommendation.py`:

```python
"""Tests for helper_recommendation module."""

import pytest


def test_normalize_city_lowercase():
    """City names are lowercased and stripped."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("London") == "london"
    assert normalize_city("  London  ") == "london"


def test_normalize_city_chinese_to_english():
    """Chinese city names are mapped to English."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("伦敦") == "london"
    assert normalize_city("曼城") == "manchester"
    assert normalize_city("爱丁堡") == "edinburgh"


def test_normalize_city_unknown_returns_none():
    """Unknown city returns None for downstream 'unknown city' handling."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("") is None
    assert normalize_city(None) is None
    assert normalize_city("Atlantis") is None  # 不在白名单
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.helper_recommendation'`

- [ ] **Step 3: 写最小实现**

`backend/app/services/helper_recommendation.py`:

```python
"""Helper recommendation by user intent.

提供 recommend_helpers() 主入口和相关纯计算函数。
被 ai_tools.py 的 recommend_helpers_by_intent 工具调用。

Spec: docs/superpowers/specs/2026-05-12-recommend-helpers-by-intent-design.md
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# 中英城市映射表 — 覆盖主要英国城市 + 北京/上海等中国大城市
# 匹配前都 lower().strip(),所以这里 key 也要小写
_CITY_ALIASES = {
    # 英国
    "伦敦": "london",
    "曼城": "manchester",
    "曼彻斯特": "manchester",
    "爱丁堡": "edinburgh",
    "伯明翰": "birmingham",
    "格拉斯哥": "glasgow",
    "布里斯托": "bristol",
    "谢菲尔德": "sheffield",
    "利兹": "leeds",
    "纽卡斯尔": "newcastle",
    "利物浦": "liverpool",
    "卡迪夫": "cardiff",
    "考文垂": "coventry",
    "诺丁汉": "nottingham",
    "南安普顿": "southampton",
    # 中国大陆
    "北京": "beijing",
    "上海": "shanghai",
    "广州": "guangzhou",
    "深圳": "shenzhen",
    "杭州": "hangzhou",
}

# 已知英文城市白名单(lower) — 不在内的视为未知城市
_KNOWN_CITIES = {
    "london", "manchester", "edinburgh", "birmingham", "glasgow",
    "bristol", "sheffield", "leeds", "newcastle", "liverpool",
    "cardiff", "coventry", "nottingham", "southampton",
    "beijing", "shanghai", "guangzhou", "shenzhen", "hangzhou",
}


def normalize_city(city: Optional[str]) -> Optional[str]:
    """Normalize a city name to canonical lowercase English.

    Returns None for empty input or unknown city (treated as "unknown city" downstream).
    """
    if not city:
        return None
    key = city.strip().lower()
    if not key:
        return None
    # 先查别名映射(中文等)
    if key in _CITY_ALIASES:
        return _CITY_ALIASES[key]
    # 再看是否已知英文
    if key in _KNOWN_CITIES:
        return key
    return None
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): 创建 helper_recommendation 模块 + 城市归一化"
```

---

## Task 2: 评分纯函数 (_geo_multiplier + _score_candidate)

**Files:**
- Modify: `backend/app/services/helper_recommendation.py`
- Modify: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写 _geo_multiplier 失败测试**

追加到 `backend/tests/test_helper_recommendation.py`:

```python
def test_geo_multiplier_offline_same_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", "london") == 1.3


def test_geo_multiplier_offline_cross_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", "manchester") == 0.4


def test_geo_multiplier_offline_unknown_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", None) == 0.6


def test_geo_multiplier_both_same_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", "london") == 1.2


def test_geo_multiplier_both_cross_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", "manchester") == 0.7


def test_geo_multiplier_both_unknown_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", None) == 0.9


def test_geo_multiplier_null_mode_treats_as_both():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier(None, "london", "london") == 1.2


def test_geo_multiplier_online_ignores_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("online", "london", "manchester") == 1.0
    assert _geo_multiplier("online", "london", None) == 1.0


def test_score_candidate_service_base():
    """service base 0.6, 无 boost, 无 geo 调整 (online)。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=None,
        completed_count=0,
        skills_overlap=0,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6)


def test_score_candidate_full_boost_clamps_to_1():
    """高 rating + 高 count + 满 skills overlap + 同城 offline → clamp 1.0。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=4.9,
        completed_count=20,  # service 池不应该用这个,但函数本身不挑
        skills_overlap=3,
        geo_multiplier=1.3,
    )
    assert s == pytest.approx(1.0)  # min(1.0, ...)


def test_score_candidate_task_history_with_boosts():
    """task_history base 0.3 + rating 4.2 (+0.10) + count 5 (+0.05) + geo 1.2 = 0.54。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="task_history",
        avg_rating=4.2,
        completed_count=5,
        skills_overlap=0,  # task_history 池不算 skills boost
        geo_multiplier=1.2,
    )
    assert s == pytest.approx(0.54)  # (0.3 + 0.10 + 0.05) * 1.2 = 0.54


def test_score_candidate_low_rating_no_boost():
    """avg_rating < 3.0 不加 boost。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=2.5,
        completed_count=0,
        skills_overlap=0,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6)  # base only


def test_score_candidate_skills_overlap_capped_at_3():
    """skills_overlap 输入 5 也只算 3 个 (max +0.15)。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=None,
        completed_count=0,
        skills_overlap=5,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6 + 0.15)  # min(5, 3) * 0.05 = 0.15
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: 13 new tests FAIL with `ImportError`.

- [ ] **Step 3: 实现两个纯函数**

追加到 `backend/app/services/helper_recommendation.py`:

```python
_GEO_TABLE = {
    # (mode, city_state) -> multiplier
    # city_state: 'same' | 'cross' | 'unknown'
    ("offline", "same"):    1.3,
    ("offline", "cross"):   0.4,
    ("offline", "unknown"): 0.6,
    ("both",    "same"):    1.2,
    ("both",    "cross"):   0.7,
    ("both",    "unknown"): 0.9,
    ("online",  "same"):    1.0,
    ("online",  "cross"):   1.0,
    ("online",  "unknown"): 1.0,
}


def _geo_multiplier(
    mode: Optional[str],
    user_city: Optional[str],
    candidate_city: Optional[str],
) -> float:
    """Multiplier based on mode + city alignment.

    mode None 视作 'both'。candidate_city None 视作 unknown。
    """
    m = mode or "both"
    if m == "online":
        return 1.0
    if candidate_city is None or user_city is None:
        state = "unknown" if candidate_city is None else "cross"
    elif candidate_city == user_city:
        state = "same"
    else:
        state = "cross"
    return _GEO_TABLE.get((m, state), 1.0)


def _score_candidate(
    source: str,
    avg_rating: Optional[float],
    completed_count: int,
    skills_overlap: int,
    geo_multiplier: float,
) -> float:
    """Compute candidate score 0..1。Caller 保证不要传 task_history 的 skills_overlap > 0。"""
    base = 0.6 if source == "service" else 0.3

    boost = 0.0
    # rating boost
    if avg_rating is not None and avg_rating >= 4.5:
        boost += 0.15
    elif avg_rating is not None and avg_rating >= 4.0:
        boost += 0.10
    # completed_count boost (主要 task_history 用,函数本身不挑)
    if completed_count >= 10:
        boost += 0.10
    elif completed_count >= 3:
        boost += 0.05
    # skills overlap
    boost += min(3, max(0, skills_overlap)) * 0.05

    return min(1.0, (base + boost) * geo_multiplier)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: 16 tests PASS (3 from Task 1 + 13 from Task 2).

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): 评分函数 _geo_multiplier + _score_candidate"
```

---

## Task 3: match_reason 生成函数

**Files:**
- Modify: `backend/app/services/helper_recommendation.py`
- Modify: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写 _build_match_reason 失败测试**

追加到 `backend/tests/test_helper_recommendation.py`:

```python
def test_match_reason_service_same_city_with_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=4.8,
        completed_count=0, task_type=None,
        city_state="same", city_display="伦敦",
    )
    assert r == "发布了陪逛服务,评分 4.8(伦敦)"


def test_match_reason_service_cross_city_with_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=4.5,
        completed_count=0, task_type=None,
        city_state="cross", city_display="曼城",
    )
    assert r == "发布了陪逛服务,评分 4.5(曼城,可线上协调)"


def test_match_reason_service_unknown_city_no_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=None,
        completed_count=0, task_type=None,
        city_state="unknown", city_display=None,
    )
    assert r == "发布了陪逛服务"


def test_match_reason_task_history_same_city():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="task_history", service_name=None, avg_rating=4.6,
        completed_count=8, task_type="accompany",
        city_state="same", city_display="伦敦",
    )
    # 任务类型用 zh label,见后面 mapping
    assert "完成过 8 个" in r
    assert "评分 4.6" in r
    assert "(伦敦)" in r


def test_match_reason_task_history_no_rating():
    """无 rating 时不展示评分段。"""
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="task_history", service_name=None, avg_rating=None,
        completed_count=3, task_type="moving",
        city_state="unknown", city_display=None,
    )
    assert "完成过 3 个" in r
    assert "评分" not in r
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py::test_match_reason_service_same_city_with_rating -v`
Expected: FAIL `ImportError: cannot import name '_build_match_reason'`.

- [ ] **Step 3: 实现 _build_match_reason + task_type label 映射**

追加到 `backend/app/services/helper_recommendation.py`:

```python
# task_type → 中文 label,展示给用户用
# 与 ai_tools.py _VALID_TASK_TYPES 对齐
_TASK_TYPE_LABEL_ZH = {
    "shopping":       "代购",
    "tutoring":       "辅导",
    "translation":    "翻译",
    "design":         "设计",
    "programming":    "编程",
    "writing":        "写作",
    "photography":    "摄影",
    "moving":         "搬家",
    "cleaning":       "清洁",
    "repair":         "维修",
    "pickup_dropoff": "接送",
    "cooking":        "厨艺",
    "language_help":  "语言陪练",
    "government":     "政务办理",
    "pet_care":       "宠物照护",
    "errand":         "跑腿",
    "accompany":      "陪同",
    "digital":        "数码协助",
    "rental_housing": "租房协助",
    "campus_life":    "校园生活",
    "second_hand":    "二手交易",
    "other":          "其他",
}


def _build_match_reason(
    *,
    source: str,
    service_name: Optional[str],
    avg_rating: Optional[float],
    completed_count: int,
    task_type: Optional[str],
    city_state: str,    # 'same' | 'cross' | 'unknown'
    city_display: Optional[str],  # 显示给用户的城市名(原始字符串,不归一化)
) -> str:
    """Build human-readable match reason for a candidate.

    Spec §6.6。
    """
    rating_seg = f",评分 {avg_rating:.1f}" if avg_rating is not None else ""
    if city_state == "same":
        city_seg = f"({city_display})" if city_display else ""
    elif city_state == "cross":
        city_seg = f"({city_display},可线上协调)" if city_display else "(可线上协调)"
    else:
        city_seg = ""

    if source == "service":
        name = service_name or "个人"
        return f"发布了{name}服务{rating_seg}{city_seg}"
    # task_history
    label = _TASK_TYPE_LABEL_ZH.get(task_type or "", task_type or "")
    return f"完成过 {completed_count} 个{label}任务{rating_seg}{city_seg}"
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: 21 tests PASS (16 + 5 new).

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): _build_match_reason + task_type 中文 label"
```

---

## Task 4: 服务发布者池查询 _fetch_service_pool

**Files:**
- Modify: `backend/app/services/helper_recommendation.py`
- Modify: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写查询函数失败测试 (mock session + execute)**

追加到 `backend/tests/test_helper_recommendation.py`:

```python
import asyncio
from unittest.mock import AsyncMock, MagicMock


def _fake_row(**kwargs):
    """Build a MagicMock row that behaves like a SQLAlchemy Row tuple."""
    row = MagicMock()
    for k, v in kwargs.items():
        setattr(row, k, v)
    return row


def test_fetch_service_pool_returns_mapped_rows():
    """SQL 结果被映射成 dict 列表。"""
    from app.services.helper_recommendation import _fetch_service_pool

    row1 = _fake_row(
        id="u_001", name="Alice", avatar_url="https://a.png", avg_rating=4.8,
        city="London", service_name="陪逛", location_type="in_person",
        skills=["陪同", "购物"],
    )
    row2 = _fake_row(
        id="u_002", name="Bob", avatar_url=None, avg_rating=None,
        city=None, service_name="代购", location_type="both",
        skills=None,
    )
    mock_db = AsyncMock()
    exec_result = MagicMock()
    exec_result.all.return_value = [row1, row2]
    mock_db.execute = AsyncMock(return_value=exec_result)

    result = asyncio.get_event_loop().run_until_complete(
        _fetch_service_pool(
            db=mock_db, current_user_id="u_caller",
            task_type="accompany", skills=["陪同"], mode="offline",
        )
    )
    assert len(result) == 2
    assert result[0]["user_id"] == "u_001"
    assert result[0]["name"] == "Alice"
    assert result[0]["source"] == "service"
    assert result[0]["service_name"] == "陪逛"
    assert result[0]["avg_rating"] == 4.8
    assert result[0]["skills"] == ["陪同", "购物"]
    assert result[1]["avg_rating"] is None
    assert result[1]["skills"] == []  # NULL → []
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py::test_fetch_service_pool_returns_mapped_rows -v`
Expected: FAIL `ImportError`.

- [ ] **Step 3: 实现 _fetch_service_pool**

追加到 `backend/app/services/helper_recommendation.py`:

```python
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


_SERVICE_POOL_SQL = text("""
SELECT u.id, u.name, u.avatar_url, u.avg_rating,
       upref.city as city,
       s.service_name, s.location_type, s.skills
FROM users u
JOIN task_expert_services s
     ON s.owner_type = 'user' AND s.owner_id = u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE s.service_type = 'personal'
  AND s.status = 'active'
  AND u.id != :current_user_id
  AND (
        s.category = :task_type
     OR (
          cardinality(:skills::text[]) > 0
          AND s.skills IS NOT NULL
          AND EXISTS (
                SELECT 1 FROM jsonb_array_elements_text(s.skills) v
                WHERE v = ANY(:skills::text[])
          )
        )
  )
  AND (
        :mode IS NULL OR :mode = 'both'
     OR (:mode = 'offline' AND s.location_type IN ('in_person', 'both'))
     OR (:mode = 'online'  AND s.location_type IN ('online',    'both'))
  )
LIMIT 100
""")


async def _fetch_service_pool(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
    skills: list[str],
    mode: Optional[str],
) -> list[dict]:
    """Fetch service-publisher pool from DB. Returns list of dicts."""
    try:
        exec_result = await db.execute(
            _SERVICE_POOL_SQL,
            {
                "current_user_id": current_user_id,
                "task_type": task_type,
                "skills": skills or [],
                "mode": mode,
            },
        )
        rows = exec_result.all()
    except Exception as e:
        logger.warning("_fetch_service_pool failed: %s", e)
        return []

    out = []
    for r in rows:
        out.append({
            "user_id": r.id,
            "name": r.name,
            "avatar_url": r.avatar_url,
            "avg_rating": float(r.avg_rating) if r.avg_rating is not None else None,
            "city": r.city,
            "service_name": r.service_name,
            "location_type": r.location_type,
            "skills": r.skills or [],  # JSONB null → []
            "source": "service",
        })
    return out
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py::test_fetch_service_pool_returns_mapped_rows -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): _fetch_service_pool 服务发布者池查询"
```

---

## Task 5: 任务完成者池查询 _fetch_task_history_pool

**Files:**
- Modify: `backend/app/services/helper_recommendation.py`
- Modify: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写查询函数失败测试**

追加到 `backend/tests/test_helper_recommendation.py`:

```python
def test_fetch_task_history_pool_returns_mapped_rows():
    from app.services.helper_recommendation import _fetch_task_history_pool

    row1 = _fake_row(
        id="u_003", name="Carol", avatar_url=None, avg_rating=4.2,
        city="Manchester", completed_count=8,
    )
    mock_db = AsyncMock()
    exec_result = MagicMock()
    exec_result.all.return_value = [row1]
    mock_db.execute = AsyncMock(return_value=exec_result)

    result = asyncio.get_event_loop().run_until_complete(
        _fetch_task_history_pool(
            db=mock_db, current_user_id="u_caller",
            task_type="moving",
        )
    )
    assert len(result) == 1
    assert result[0]["user_id"] == "u_003"
    assert result[0]["source"] == "task_history"
    assert result[0]["completed_count"] == 8
    assert result[0]["avg_rating"] == 4.2
    assert result[0]["task_type"] == "moving"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py::test_fetch_task_history_pool_returns_mapped_rows -v`
Expected: FAIL `ImportError`.

- [ ] **Step 3: 实现 _fetch_task_history_pool**

追加到 `backend/app/services/helper_recommendation.py`:

```python
_TASK_HISTORY_POOL_SQL = text("""
SELECT u.id, u.name, u.avatar_url,
       upref.city as city,
       COUNT(t.id) as completed_count,
       AVG(r.rating)::float as avg_rating
FROM users u
JOIN tasks t ON t.taker_id = u.id
LEFT JOIN reviews r ON r.task_id = t.id AND r.user_id != u.id
LEFT JOIN user_profile_preferences upref ON upref.user_id = u.id
WHERE t.status = 'completed'
  AND t.task_type = :task_type
  AND u.id != :current_user_id
GROUP BY u.id, u.name, u.avatar_url, upref.city
HAVING COUNT(t.id) >= 1
LIMIT 100
""")


async def _fetch_task_history_pool(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
) -> list[dict]:
    """Fetch task-completion-history pool. Returns list of dicts."""
    try:
        exec_result = await db.execute(
            _TASK_HISTORY_POOL_SQL,
            {"current_user_id": current_user_id, "task_type": task_type},
        )
        rows = exec_result.all()
    except Exception as e:
        logger.warning("_fetch_task_history_pool failed: %s", e)
        return []

    out = []
    for r in rows:
        out.append({
            "user_id": r.id,
            "name": r.name,
            "avatar_url": r.avatar_url,
            "avg_rating": float(r.avg_rating) if r.avg_rating is not None else None,
            "city": r.city,
            "completed_count": int(r.completed_count or 0),
            "task_type": task_type,
            "source": "task_history",
        })
    return out
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py::test_fetch_task_history_pool_returns_mapped_rows -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): _fetch_task_history_pool 任务完成者池查询"
```

---

## Task 6: 主入口 recommend_helpers (合并 + 评分 + 排序)

**Files:**
- Modify: `backend/app/services/helper_recommendation.py`
- Modify: `backend/tests/test_helper_recommendation.py`

- [ ] **Step 1: 写主函数失败测试**

追加到 `backend/tests/test_helper_recommendation.py`:

```python
def test_recommend_helpers_merges_and_sorts():
    """两池都返回数据,合并去重,按 score desc 排序,服务源加权高。"""
    from app.services import helper_recommendation as hr

    mock_db = AsyncMock()
    # Mock user_city 查询 (current user 的 city)
    user_pref_row = _fake_row(city="London")
    user_pref_result = MagicMock()
    user_pref_result.first.return_value = user_pref_row

    # Service pool returns Alice (London,陪逛,rating 4.8)
    service_row = _fake_row(
        id="u_001", name="Alice", avatar_url=None, avg_rating=4.8,
        city="London", service_name="陪逛", location_type="in_person",
        skills=["陪同"],
    )
    service_result = MagicMock()
    service_result.all.return_value = [service_row]

    # Task history pool returns Bob (Manchester,4 completed,rating 4.2)
    history_row = _fake_row(
        id="u_002", name="Bob", avatar_url=None, avg_rating=4.2,
        city="Manchester", completed_count=4,
    )
    history_result = MagicMock()
    history_result.all.return_value = [history_row]

    # execute 按调用顺序返回上面 3 个结果
    mock_db.execute = AsyncMock(side_effect=[
        user_pref_result, service_result, history_result,
    ])

    out = asyncio.get_event_loop().run_until_complete(
        hr.recommend_helpers(
            db=mock_db, current_user_id="u_caller",
            task_type="accompany", skills=["陪同"],
            location=None,  # 让函数从 user pref 查
            mode="offline", limit=5,
        )
    )

    assert len(out["helpers"]) == 2
    # Alice 同城 service base 0.6 + rating 0.15 + skills 0.05 × 1.3 = 1.04 → 1.0
    # Bob 跨城 task_history base 0.3 + rating 0.10 + count 0.05 × 0.4 = 0.18
    assert out["helpers"][0]["user_id"] == "u_001"  # Alice 排第一
    assert out["helpers"][0]["match_score"] > out["helpers"][1]["match_score"]
    assert out["helpers"][0]["source"] == "service"
    assert out["helpers"][0]["profile_url"] == "/profile/u_001"
    assert "陪逛" in out["helpers"][0]["match_reason"]
    assert "伦敦" in out["helpers"][0]["match_reason"] or "London" in out["helpers"][0]["match_reason"]
    assert out["total"] == 2
    assert out["fallback_suggestion"] is None


def test_recommend_helpers_empty_returns_fallback():
    """两池都空,返回 fallback_suggestion 提示发任务。"""
    from app.services import helper_recommendation as hr

    mock_db = AsyncMock()
    user_pref_result = MagicMock()
    user_pref_result.first.return_value = _fake_row(city="London")
    empty_result = MagicMock()
    empty_result.all.return_value = []
    mock_db.execute = AsyncMock(side_effect=[
        user_pref_result, empty_result, empty_result,
    ])

    out = asyncio.get_event_loop().run_until_complete(
        hr.recommend_helpers(
            db=mock_db, current_user_id="u_caller",
            task_type="moving", skills=[], location="London",
            mode="offline", limit=5,
        )
    )
    assert out["helpers"] == []
    assert out["total"] == 0
    assert out["fallback_suggestion"] is not None
    assert "London" in out["fallback_suggestion"] or "伦敦" in out["fallback_suggestion"]


def test_recommend_helpers_dedupes_same_user_keeps_service():
    """同一 user_id 出现在两池,合并后取 max score,source 标 service。"""
    from app.services import helper_recommendation as hr

    mock_db = AsyncMock()
    user_pref_result = MagicMock()
    user_pref_result.first.return_value = _fake_row(city=None)  # caller 无城市
    # 两池都返回 u_001
    service_row = _fake_row(
        id="u_001", name="Alice", avatar_url=None, avg_rating=4.8,
        city="London", service_name="陪逛", location_type="in_person", skills=[],
    )
    service_result = MagicMock()
    service_result.all.return_value = [service_row]
    history_row = _fake_row(
        id="u_001", name="Alice", avatar_url=None, avg_rating=4.5,
        city="London", completed_count=5,
    )
    history_result = MagicMock()
    history_result.all.return_value = [history_row]
    mock_db.execute = AsyncMock(side_effect=[
        user_pref_result, service_result, history_result,
    ])

    out = asyncio.get_event_loop().run_until_complete(
        hr.recommend_helpers(
            db=mock_db, current_user_id="u_caller",
            task_type="accompany", skills=[], location=None,
            mode="online", limit=5,
        )
    )
    assert len(out["helpers"]) == 1
    assert out["helpers"][0]["user_id"] == "u_001"
    assert out["helpers"][0]["source"] == "service"  # 高源胜出
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v -k "test_recommend_helpers"`
Expected: 3 tests FAIL with `AttributeError: module ... has no attribute 'recommend_helpers'`.

- [ ] **Step 3: 实现 recommend_helpers + 辅助函数**

追加到 `backend/app/services/helper_recommendation.py`:

```python
_USER_CITY_SQL = text("""
SELECT upref.city
FROM user_profile_preferences upref
WHERE upref.user_id = :user_id
LIMIT 1
""")


async def _get_user_city(db: AsyncSession, user_id: str) -> Optional[str]:
    """Fetch caller's city from preferences. None if not set."""
    try:
        result = await db.execute(_USER_CITY_SQL, {"user_id": user_id})
        row = result.first()
        return row.city if row else None
    except Exception as e:
        logger.warning("_get_user_city failed: %s", e)
        return None


def _city_state(
    user_city_norm: Optional[str],
    candidate_city_norm: Optional[str],
) -> str:
    """Classify city alignment: 'same' | 'cross' | 'unknown'.

    'unknown' 用于 candidate 城市未填(数据缺失)。
    user 城市未填时(也走 unknown) 候选所有人对 user 都是"未知城市"档。
    """
    if candidate_city_norm is None:
        return "unknown"
    if user_city_norm is None:
        return "unknown"
    return "same" if candidate_city_norm == user_city_norm else "cross"


async def recommend_helpers(
    *,
    db: AsyncSession,
    current_user_id: str,
    task_type: str,
    skills: list[str],
    location: Optional[str],
    mode: Optional[str],
    limit: int = 5,
) -> dict:
    """Main entry: 两池查询 → 合并去重 → 评分 → 排序 → top N.

    Spec §4-§6。

    Returns dict matching the tool output schema (helpers/total/fallback_suggestion)。
    """
    limit = max(1, min(10, limit))

    # 1. 确定 user_city:工具入参 location 优先,fallback 到 user_profile_preferences.city
    raw_user_city = location or await _get_user_city(db, current_user_id)
    user_city_norm = normalize_city(raw_user_city)

    # 2. 两池并行(简单串行也行,QPS 低)
    service_pool = await _fetch_service_pool(
        db=db, current_user_id=current_user_id,
        task_type=task_type, skills=skills or [], mode=mode,
    )
    history_pool = await _fetch_task_history_pool(
        db=db, current_user_id=current_user_id, task_type=task_type,
    )

    # 3. 评分 + 合并去重(同 user_id 取 max score,source 优先 service)
    scored: dict[str, dict] = {}  # user_id -> candidate dict (含 score + meta)

    for cand in service_pool:
        cand_city_norm = normalize_city(cand["city"])
        state = _city_state(user_city_norm, cand_city_norm)
        geo_mult = _geo_multiplier(mode, user_city_norm, cand_city_norm)
        skills_overlap = len(set(cand.get("skills") or []) & set(skills or []))
        score = _score_candidate(
            source="service", avg_rating=cand.get("avg_rating"),
            completed_count=0, skills_overlap=skills_overlap, geo_multiplier=geo_mult,
        )
        scored[cand["user_id"]] = {
            **cand, "score": score, "city_state": state,
            "city_display": cand.get("city"),
        }

    for cand in history_pool:
        cand_city_norm = normalize_city(cand["city"])
        state = _city_state(user_city_norm, cand_city_norm)
        geo_mult = _geo_multiplier(mode, user_city_norm, cand_city_norm)
        score = _score_candidate(
            source="task_history", avg_rating=cand.get("avg_rating"),
            completed_count=cand.get("completed_count", 0),
            skills_overlap=0, geo_multiplier=geo_mult,
        )
        uid = cand["user_id"]
        if uid in scored:
            # 已有 service 源候选,取 max score 但保留 service source
            if score > scored[uid]["score"]:
                scored[uid]["score"] = score
            # service 字段保留,不覆盖
        else:
            scored[uid] = {
                **cand, "score": score, "city_state": state,
                "city_display": cand.get("city"),
            }

    # 4. 排序 + top N
    ranked = sorted(scored.values(), key=lambda c: c["score"], reverse=True)[:limit]

    # 5. 构建 output
    helpers = []
    for c in ranked:
        helpers.append({
            "user_id": c["user_id"],
            "name": c["name"],
            "avatar_url": c.get("avatar_url"),
            "source": c["source"],
            "match_score": round(c["score"], 3),
            "match_reason": _build_match_reason(
                source=c["source"],
                service_name=c.get("service_name"),
                avg_rating=c.get("avg_rating"),
                completed_count=c.get("completed_count", 0),
                task_type=c.get("task_type"),
                city_state=c["city_state"],
                city_display=c["city_display"],
            ),
            "profile_url": f"/profile/{c['user_id']}",
        })

    # 6. fallback_suggestion (空时)
    fallback = None
    if not helpers:
        loc_str = raw_user_city or location
        if loc_str:
            fallback = f"{loc_str} 暂时还没有合适的人选,建议你发个任务让大家看到"
        else:
            fallback = "还没有匹配的人选,建议你发个任务让大家看到"

    logger.info(
        "recommend_helpers: user=%s task_type=%s mode=%s loc=%s n_results=%d",
        current_user_id, task_type, mode, raw_user_city, len(helpers),
    )

    return {
        "helpers": helpers,
        "total": len(helpers),
        "fallback_suggestion": fallback,
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd backend && pytest tests/test_helper_recommendation.py -v`
Expected: 24 tests PASS (21 + 3 new).

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/helper_recommendation.py backend/tests/test_helper_recommendation.py
git commit -m "feat(helper-rec): recommend_helpers 主入口 — 合并/评分/排序/fallback"
```

---

## Task 7: 注册 AI 工具 recommend_helpers_by_intent

**Files:**
- Modify: `backend/app/services/ai_tools.py` (在文件末尾或合适位置注册)

- [ ] **Step 1: 准备工具注册代码**

定位 `_recommend_takers` 注册段(`ai_tools.py:2321`),在其后插入新工具注册。

- [ ] **Step 2: 写工具注册代码**

在 `backend/app/services/ai_tools.py` 适当位置(建议 `_recommend_takers` 之后,line 2321 附近)插入:

```python
@tool_registry.register(
    name="recommend_helpers_by_intent",
    description=(
        "基于用户聊天里表达的需求,直接推荐合适的人选(不需要用户先发布任务)。"
        "Recommend helpers based on user's expressed intent in chat, without requiring a posted task."
    ),
    input_schema={
        "type": "object",
        "properties": {
            "task_type": {
                "type": "string",
                "description": "任务类型,来自 TASK_TYPES 枚举(必填)",
            },
            "skills": {
                "type": "array",
                "items": {"type": "string"},
                "description": "1-3 个关键技能词(可空)",
            },
            "location": {
                "type": "string",
                "description": "城市/区域名(可空,会从用户画像兜底)",
            },
            "mode": {
                "type": "string",
                "enum": ["online", "offline", "both"],
                "description": "需求模式(可空,默认 both)",
            },
            "limit": {
                "type": "integer",
                "description": "返回数量,默认 5,最大 10",
                "default": 5,
            },
        },
        "required": ["task_type"],
    },
    categories=[ToolCategory.TASK],
)
async def _recommend_helpers_by_intent(executor: ToolExecutor, input: dict) -> dict:
    task_type = input.get("task_type")
    if not task_type or task_type not in _VALID_TASK_TYPES:
        return {"error": "invalid_task_type"}

    skills = input.get("skills") or []
    if not isinstance(skills, list):
        skills = []
    location = input.get("location")
    mode = input.get("mode")
    if mode not in (None, "online", "offline", "both"):
        mode = None
    limit = input.get("limit", 5)

    try:
        from app.services.helper_recommendation import recommend_helpers
        return await recommend_helpers(
            db=executor.db,
            current_user_id=executor.user.id,
            task_type=task_type,
            skills=skills[:3],  # 最多取前 3 个
            location=location,
            mode=mode,
            limit=limit,
        )
    except Exception as e:
        logger.warning("recommend_helpers_by_intent failed: %s", e)
        return {"error": "internal_error"}
```

- [ ] **Step 3: 验证注册没语法错误**

Run: `cd backend && python -c "from app.services import ai_tools; print([t for t in dir(ai_tools) if 'helpers' in t.lower()])"`
Expected: 输出包含 `_recommend_helpers_by_intent`,无 import error。

- [ ] **Step 4: 验证工具被注册到 registry**

Run: `cd backend && python -c "from app.services.ai_tools import tool_registry; print('recommend_helpers_by_intent' in [t.name for t in tool_registry._tools.values()])"`

(若 tool_registry 结构是 dict, 调整成 `tool_registry._tools` 实际属性名;如不确定可改成 `print(dir(tool_registry))` 先看)

Expected: `True`

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_tools.py
git commit -m "feat(ai-tools): 注册 recommend_helpers_by_intent 工具"
```

---

## Task 8: System prompt 改动

**Files:**
- Modify: `backend/app/services/ai_agent.py` (改 `_DEFAULT_SYSTEM_PROMPT` 字符串)

- [ ] **Step 1: 定位职责列表 #19 之后**

Read `backend/app/services/ai_agent.py:436-520` 找到 `_DEFAULT_SYSTEM_PROMPT` 的"职责范围"列表(目前到 #19)。

- [ ] **Step 2: 加职责 #20**

在职责列表里, `19. 根据任务状态引导用户下一步操作...` 之后加:

```
20. 当用户表达具体需求时,主动提议基于平台数据推荐合适的人选
```

- [ ] **Step 3: 加触发规则段(在 prepare_service_draft 段之后, "严格禁止" 之前)**

定位 `_DEFAULT_SYSTEM_PROMPT` 里的"【发布个人服务 — 草稿模式】"段(line 493-498)结束之后, "【严格禁止 — 必须拒绝的请求】"段之前,插入:

```
【主动推荐合适的人 — 意图模式】
当用户在聊天中表达了具体需求(如"周末想找人陪我去逛街"、"需要有人帮我搬家"、
"有谁能教我英语"),且需求清晰到可以推断 task_type 时:

1. **不要直接** 调 recommend_helpers_by_intent 工具
2. **先用文本** 问确认:"看起来你想找{需求描述}的人。要我基于平台数据
   给你推荐几位合适的吗?"
3. 用户答 yes / 好 / 可以 / 嗯 等肯定后,再调 recommend_helpers_by_intent
4. 用户答 no 或说"先帮我发任务" → 改走 prepare_task_draft

工具入参提取规则:
- task_type:必填,从 TASK_TYPES 枚举中选最贴近的
- skills:从需求里抽 1-3 个关键技能词
- mode:陪逛/搬家/家教面授等需见面 → "offline";翻译/线上咨询/审稿 → "online";
  不确定 → "both"
- location:用户聊天明说优先;其次用用户画像中的城市;都没有且 mode=offline 时
  **先文本问"你在哪个城市?"**,拿到再调工具

收到结果后的回复策略:
- helpers 非空:简短一句"为你找到 N 个合适的人选,点击下方卡片看 ta 的主页 👇"
  —— 不要逐个念 match_reason(前端会展示)
- helpers 空:把 fallback_suggestion 转给用户

与 prepare_task_draft 的关系:
- prepare_task_draft:用户明确说"帮我发任务"
- recommend_helpers_by_intent:用户只表达需求 → 主动提议"先看看人"
- 看人后用户说"我想定 ta" → 改走 prepare_task_draft
```

- [ ] **Step 4: 验证 Python 语法**

Run: `cd backend && python -m py_compile app/services/ai_agent.py`
Expected: 无输出(无错误)。

- [ ] **Step 5: 提醒 (不动手) — 如果 prod 设了 AI_SYSTEM_PROMPT_SOURCE=db**

部署 checklist 会有"同步把 admin 后台 prompt 加这段"。这步代码里不做,提醒用户。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/ai_agent.py
git commit -m "feat(ai-prompt): 加 recommend_helpers_by_intent 触发规则段"
```

---

## Task 9: Flutter HelperCard 渲染 + helpers 分支

**Files:**
- Modify: `link2ur/lib/features/ai_chat/views/unified_chat_view.dart` (`hasTaskCards` const list 加 `'helpers'`)
- Modify: `link2ur/lib/features/ai_chat/widgets/task_result_cards.dart` (加 helpers 分支 + `_HelperCard`)

- [ ] **Step 1: Read task_result_cards.dart 当前结构**

Read: `link2ur/lib/features/ai_chat/widgets/task_result_cards.dart` 完整内容,定位 `TaskResultCards` 的 `build` 方法和现有 5 类分支(tasks/services/experts/items/posts)。

- [ ] **Step 2: 在 unified_chat_view.dart 的 hasTaskCards 加 'helpers'**

定位 `link2ur/lib/features/ai_chat/views/unified_chat_view.dart` 里的:

```dart
final hasTaskCards = rd != null && const ['tasks', 'services', 'experts', 'items', 'posts']
    .any((k) => rd[k] is List && (rd[k] as List).isNotEmpty);
```

改为:

```dart
final hasTaskCards = rd != null && const ['tasks', 'services', 'experts', 'items', 'posts', 'helpers']
    .any((k) => rd[k] is List && (rd[k] as List).isNotEmpty);
```

- [ ] **Step 3: 在 task_result_cards.dart 加 helpers 渲染分支**

在 `TaskResultCards` 的 `build` 方法里,找到现有 `if (toolResult['posts'] is List ...)` 之类的分支末尾,加:

```dart
if (toolResult['helpers'] is List &&
    (toolResult['helpers'] as List).isNotEmpty) {
  return _buildHelperList(
    toolResult['helpers'] as List,
    context,
  );
}
```

并在文件底部加内部 widget(参考其他 _build* 函数的样式):

```dart
Widget _buildHelperList(List helpers, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: helpers.map<Widget>((h) {
        if (h is! Map) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _HelperCard(data: h.cast<String, dynamic>()),
        );
      }).toList(),
    ),
  );
}

class _HelperCard extends StatelessWidget {
  const _HelperCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = (data['name'] as String?) ?? '';
    final avatarUrl = data['avatar_url'] as String?;
    final matchReason = (data['match_reason'] as String?) ?? '';
    final profileUrl = (data['profile_url'] as String?) ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: profileUrl.isEmpty
            ? null
            : () => context.push(profileUrl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : const Color(0xFFE5E5EA),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name.characters.first : '?',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      matchReason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
```

确保 imports 含:
- `package:go_router/go_router.dart` (for `context.push`)
- `core/design/app_colors.dart`, `app_radius.dart`, `app_spacing.dart`
- `flutter/material.dart`

(若 import 已存在则跳过)

- [ ] **Step 4: flutter analyze 验证零 issue**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
cd link2ur
flutter analyze lib/features/ai_chat/widgets/task_result_cards.dart lib/features/ai_chat/views/unified_chat_view.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/ai_chat/widgets/task_result_cards.dart link2ur/lib/features/ai_chat/views/unified_chat_view.dart
git commit -m "feat(flutter/ai-chat): 渲染 helpers 推荐卡片 (跳 profile)"
```

---

## Task 10: HelperCard widget 测试

**Files:**
- Create: `link2ur/test/features/ai_chat/widgets/helper_card_test.dart`

- [ ] **Step 1: 写 widget 测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/features/ai_chat/widgets/task_result_cards.dart';

// 用 GoRouter mock 测点击跳转
GoRouter _testRouter(List<String> capturedPushes) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (_, __) => Scaffold(
          body: TaskResultCards(toolResult: {
            'helpers': [
              {
                'user_id': 'u_001',
                'name': 'Alice',
                'avatar_url': null,
                'source': 'service',
                'match_score': 0.92,
                'match_reason': '发布了陪逛服务,评分 4.8(伦敦)',
                'profile_url': '/profile/u_001',
              },
            ],
          }),
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        redirect: (_, state) {
          capturedPushes.add(state.uri.path);
          return '/test';  // bounce back to keep widget alive
        },
        builder: (_, __) => const SizedBox(),
      ),
    ],
  );
}

void main() {
  testWidgets('HelperCard renders name and match_reason', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter([])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('发布了陪逛服务,评分 4.8(伦敦)'), findsOneWidget);
  });

  testWidgets('Tapping HelperCard navigates to profile_url', (tester) async {
    final captured = <String>[];
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(captured)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(captured, contains('/profile/u_001'));
  });

  testWidgets('Empty helpers list renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskResultCards(toolResult: const {'helpers': []}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 不应该渲染任何 HelperCard
    expect(find.text('Alice'), findsNothing);
  });
}
```

- [ ] **Step 2: 跑 widget 测试**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
cd link2ur
flutter test test/features/ai_chat/widgets/helper_card_test.dart
```

Expected: All 3 tests PASS。

- [ ] **Step 3: 修复 (如果失败)**

常见失败原因:
- `helper_card_test.dart` 顶部 import path 跟实际 package name 不一致 → 改成 `package:link2ur/...` 或 `package:<实际包名>/...` (查 `link2ur/pubspec.yaml` 的 `name:` 字段)
- 路由重定向不工作 → 改用直接捕获 `context.push` 拦截方式

- [ ] **Step 4: Commit**

```bash
git add link2ur/test/features/ai_chat/widgets/helper_card_test.dart
git commit -m "test(flutter/ai-chat): HelperCard widget 测试 — 渲染 + 点击跳转"
```

---

## Task 11: 文档更新

**Files:**
- Modify: `backend/docs/ai-agent.md`

- [ ] **Step 1: 找到工具列表段**

Grep `backend/docs/ai-agent.md` 找已注册工具的列表(估计在工具数 37 / 37+ 的位置)。

Run: `grep -n "工具" backend/docs/ai-agent.md | head -20`

- [ ] **Step 2: 加新工具简介**

在工具列表合适位置加一行:

```
- `recommend_helpers_by_intent` — 基于用户聊天意图主动推荐合适的人选(候选池=服务发布者 ∪ 同类任务完成者),仅返回候选卡片跳 profile,不直接发任务
```

并把工具总数从 37 改为 38(如果文档里有这数字)。

- [ ] **Step 3: Commit**

```bash
git add backend/docs/ai-agent.md
git commit -m "docs(ai-agent): 加 recommend_helpers_by_intent 工具说明"
```

---

## Task 12: 整体 smoke test (手动,不写测试代码)

- [ ] **Step 1: 启动 backend dev**

Run: `cd backend && uvicorn app.main:app --reload`

确认无 import error,启动成功。

- [ ] **Step 2: 启动 Flutter app**

Run:
```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
cd link2ur
flutter run -d web-server
```

打开浏览器进 AI 聊天页。

- [ ] **Step 3: 跑 3 个场景验证触发链路**

**场景 A (陪逛/offline):**
- 输入:"周末想找人陪我去逛街"
- 期望:AI 文本回复"看起来你想找人陪你逛街。要我基于平台数据给你推荐几位合适的吗?"
- 答"好"
- 期望:AI 调用 `recommend_helpers_by_intent`,如果 dev 数据库有数据 → 返回 helper 卡片;否则返回 fallback_suggestion 文本

**场景 B (翻译/online):**
- 输入:"需要找人帮我翻译一份合同"
- 期望:AI 先文本确认,用户同意后调工具,mode=online,不要求 location

**场景 C (搬家但没说城市):**
- 输入:"下周需要搬家,谁能帮我?"
- 期望:AI 先问"你在哪个城市?"(因为 mode=offline 且 location 没在聊天 + user pref 也没设),拿到后再调工具

- [ ] **Step 4: 检查日志**

观察 backend logs 是否有 `recommend_helpers: user=... task_type=... mode=... loc=... n_results=...` 这种行。

- [ ] **Step 5: 如发现 prod AI_SYSTEM_PROMPT_SOURCE=db,同步 admin 后台 prompt**

(deployment-only,如不部署 prod 可跳过)

进 admin 面板的 `/admin/ai-prompt` 编辑器,把 Task 8 加的"【主动推荐合适的人 — 意图模式】"段同步进去保存。

- [ ] **Step 6: 不需要 commit (这是 smoke test,无代码变更)**

---

## Self-Review

### Spec coverage check

| Spec 节 | 实现 task |
|---|---|
| §4 整体架构 | Task 7 (工具注册) + Task 8 (prompt) 共同实现 |
| §5 input/output schema | Task 7 工具 input_schema + Task 6 主函数 return |
| §6.1 SQL 候选池 | Task 4 + Task 5 |
| §6.2 评分公式 | Task 2 |
| §6.3 地点加权 | Task 2 (_geo_multiplier) |
| §6.4 合并去重 | Task 6 |
| §6.5 城市归一化 | Task 1 |
| §6.6 match_reason | Task 3 |
| §6.7 fallback_suggestion | Task 6 |
| §6.8 实现位置 | Task 1-6 (helper_recommendation.py) + Task 7 (ai_tools.py) |
| §7 system prompt | Task 8 |
| §8 Flutter 渲染 | Task 9 |
| §9 错误处理 | Task 7 (invalid_task_type + internal_error) + Task 4/5 (DB try/except) |
| §10 测试 | Task 1-6 (backend pytest) + Task 10 (Flutter widget test) + Task 12 (smoke) |
| §11 监控日志 | Task 6 内置 logger.info |
| §12 部署 checklist | Task 12 step 5 (admin prompt 同步) |

全部覆盖。

### Placeholder 扫描

无 TBD / TODO / "implement later"。所有 step 都有完整代码块或可执行命令。

### Type consistency 扫描

- 候选 dict 字段名一致:`user_id`, `name`, `avatar_url`, `avg_rating`, `city`, `source`(在 Task 4/5/6 都用同样命名)
- `_score_candidate` 入参在 Task 2 定义,Task 6 调用,签名一致
- `_build_match_reason` Task 3 定义,Task 6 调用,签名一致
- 工具返回字段 `helpers / total / fallback_suggestion` 在 Task 6 和 Task 7 一致

无不一致。

---

Plan complete and saved to `docs/superpowers/plans/2026-05-12-recommend-helpers-by-intent.md`. Two execution options:

**1. Subagent-Driven (recommended)** — 我每个 task dispatch 一个 fresh subagent,task 间 review,快速迭代
**2. Inline Execution** — 在当前会话里执行,批量执行 + 检查点

Which approach?
