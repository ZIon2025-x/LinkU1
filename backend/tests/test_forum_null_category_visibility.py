"""Test NULL category visibility behavior (spec 2026-05-15 Part 1 critical risk).

Spec rules:
1. NULL 帖出现在社区发现流（discovery 列表 SQL filter 加 OR category_id IS NULL）
2. NULL 帖不出现在具体板块详情页（用户主动传 category_id=X 路径不变）
3. NULL 帖可被单帖详情读取（assert_forum_visible 顶部 None 短路）
4. NULL 帖可被点赞 / 评论 / 收藏（互动路径同样靠 None 短路覆盖）
5. 通知里 NULL category 视为可见

测试形式：源码 / AST 检查 — 不走端到端 HTTP（仓库的 conftest 没有 in-process
TestClient + secure-auth session fixture）。
"""
from __future__ import annotations

import ast
import pathlib
import re

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
FORUM_ROUTES = REPO_ROOT / "app" / "forum_routes.py"
FORUM_DISCOVERY = REPO_ROOT / "app" / "routes" / "forum_discovery_routes.py"
FORUM_MY = REPO_ROOT / "app" / "routes" / "forum_my_routes.py"
FORUM_POSTS = REPO_ROOT / "app" / "routes" / "forum_posts_routes.py"
AI_TOOLS = REPO_ROOT / "app" / "services" / "ai_tools.py"


def _load_function_source(path: pathlib.Path, func_name: str) -> str:
    """Return the source of a top-level function by name."""
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == func_name:
            return ast.get_source_segment(source, node) or ""
    raise AssertionError(f"function {func_name} not found in {path}")


# ============================================================
# Step 1: helper assert_forum_visible 顶部短路
# ============================================================

def test_assert_forum_visible_short_circuits_on_none():
    """NULL category should be treated as visible to everyone (helper-level short-circuit)."""
    src = _load_function_source(FORUM_ROUTES, "assert_forum_visible")

    # 短路必须在函数体前段
    assert "if forum_id is None:" in src, (
        "assert_forum_visible 顶部缺少 `if forum_id is None: return True` 短路"
    )

    # `return True` 必须紧跟其后（在数据库查询之前）
    none_check_idx = src.find("if forum_id is None:")
    db_query_idx = src.find("db.execute(")
    assert 0 <= none_check_idx < db_query_idx, (
        "None 短路必须出现在 db.execute() 之前，否则白做"
    )

    # 类型注解也应改成 Optional
    assert "forum_id: Optional[int]" in src, (
        "assert_forum_visible 的 forum_id 形参类型应改为 Optional[int]"
    )


# ============================================================
# Step 2: discovery 列表 SQL filter
# ============================================================

def test_discovery_filter_includes_null_category():
    """所有 visible_category_ids.in_() 调用必须 OR category_id IS NULL"""
    src = FORUM_DISCOVERY.read_text(encoding="utf-8")

    # 每个 visible_category_ids.in_( 调用前后 250 字符应包含 'is_(None)' 或 'or_('
    pattern = re.compile(r"models\.ForumPost\.category_id\.in_\(visible_category_ids\)")
    matches = list(pattern.finditer(src))
    assert matches, "至少应有一处 visible_category_ids.in_() 调用（grep 检查没找到）"

    for m in matches:
        window = src[max(0, m.start() - 250):m.end() + 250]
        assert ("is_(None)" in window) and ("or_(" in window), (
            f"forum_discovery_routes.py 位置 {m.start()} 的 visible_category_ids.in_() "
            f"没和 or_(..., is_(None)) 配对\nWindow:\n{window}"
        )


def test_discovery_empty_visible_falls_back_to_null():
    """无任何可见 categories 时，filter 应至少让 NULL 帖可见（不要 -1 兜底）"""
    src = FORUM_DISCOVERY.read_text(encoding="utf-8")

    # 旧的 `category_id == -1` 兜底必须全部清除
    assert "category_id == -1" not in src, (
        "discovery 路由还保留 `category_id == -1` 死兜底，应换成 `category_id.is_(None)`"
    )


# ============================================================
# Step 3: notification visibility 4 处
# ============================================================

def test_notification_visibility_allows_null():
    """通知可见性 4 处应允许 category_id is None"""
    src = FORUM_DISCOVERY.read_text(encoding="utf-8")

    # 旧形式 "if category_id and category_id in visible_category_ids" 应当被消灭
    bad_pattern = re.compile(r"if\s+category_id\s+and\s+category_id\s+in\s+visible_category_ids")
    bad_matches = bad_pattern.findall(src)
    assert not bad_matches, (
        f"forum_discovery_routes.py 还有 {len(bad_matches)} 处旧形式 "
        "(category_id and category_id in visible_ids), 需改为 'is None or ... in ...'"
    )

    # 新形式 "if category_id is None or category_id in visible_category_ids" 应至少 4 处
    good_pattern = re.compile(
        r"if\s+category_id\s+is\s+None\s+or\s+category_id\s+in\s+visible_category_ids"
    )
    good_matches = good_pattern.findall(src)
    assert len(good_matches) >= 4, (
        f"forum_discovery_routes.py 应有 >=4 处 'category_id is None or ... in ...' "
        f"通知 visibility 模式，但只找到 {len(good_matches)} 处"
    )


# ============================================================
# Step 4: forum_my_routes 同改造
# ============================================================

def test_forum_my_python_guard_allows_null():
    """forum_my_routes.py 的 Python 层过滤应跳过 NULL"""
    src = FORUM_MY.read_text(encoding="utf-8")

    # 旧形式 `if post.category_id not in visible_category_ids: continue` 不应单独存在
    bad_pattern = re.compile(
        r"if\s+post\.category_id\s+not\s+in\s+visible_category_ids\s*:"
    )
    bad_matches = bad_pattern.findall(src)
    assert not bad_matches, (
        "forum_my_routes.py 还有未加 NULL 守卫的 `if post.category_id not in visible_category_ids` 条件"
    )

    # 新形式必须包含 `is not None and`
    good_pattern = re.compile(
        r"post\.category_id\s+is\s+not\s+None\s+and\s+post\.category_id\s+not\s+in\s+visible_category_ids"
    )
    assert good_pattern.search(src), (
        "forum_my_routes.py 缺少 `post.category_id is not None and ... not in visible_category_ids` 守卫"
    )


def test_forum_my_sql_filter_includes_null():
    """forum_my_routes.py 的 SQL filter 也得加 OR NULL"""
    src = FORUM_MY.read_text(encoding="utf-8")

    pattern = re.compile(r"models\.ForumPost\.category_id\.in_\(visible_category_ids\)")
    for m in pattern.finditer(src):
        window = src[max(0, m.start() - 200):m.end() + 200]
        assert "is_(None)" in window, (
            f"forum_my_routes.py 位置 {m.start()} 的 SQL filter 缺 OR is_(None)"
        )


# ============================================================
# Step 5: 响应构造时 post.category 可能为 None
# ============================================================

def test_response_builder_handles_none_category():
    """category=schemas.CategoryInfo(...) 必须在 None category 时优雅 None"""
    # forum_discovery_routes.py / forum_my_routes.py / forum_posts_routes.py 中所有
    # `category=schemas.CategoryInfo(id=post.category.id ...)` 模式必须跟 `if post.category else None`
    for path in (FORUM_DISCOVERY, FORUM_MY, FORUM_POSTS):
        src = path.read_text(encoding="utf-8")
        # 匹配未守卫的写法（行末是 `, name_zh=...name_zh),`，没有 ` if ... else None`）
        bare_pattern = re.compile(
            r"category=schemas\.CategoryInfo\([^)]*name_zh=(?:db_post|post)\.category\.name_zh\)\s*,"
        )
        bare_matches = bare_pattern.findall(src)
        assert not bare_matches, (
            f"{path.name} 还有 {len(bare_matches)} 处未守卫的 "
            "`category=schemas.CategoryInfo(...).name_zh)` 调用，缺 ` if (db_)post.category else None`"
        )


# ============================================================
# Step 6: ai_tools 中 forum search 也要兼容 NULL
# ============================================================

def test_ai_tools_forum_search_includes_null():
    """AI tool 搜索 forum 时也应包含 NULL category 帖子"""
    src = AI_TOOLS.read_text(encoding="utf-8")

    pattern = re.compile(r"models\.ForumPost\.category_id\.in_\(allowed_cat_ids\)")
    matches = list(pattern.finditer(src))
    assert matches, "AI tools 里应至少有一处 allowed_cat_ids.in_() 用法"

    for m in matches:
        window = src[max(0, m.start() - 200):m.end() + 200]
        assert "is_(None)" in window, (
            f"ai_tools.py 位置 {m.start()} 缺 `category_id.is_(None)` 兜底"
        )


# ============================================================
# Step 7: message_routes 通知 visibility 2 处 (C2 follow-up)
# ============================================================

def test_message_routes_notification_visibility_allows_null():
    """message_routes.py 通知可见性 2 处应允许 NULL category"""
    src = (REPO_ROOT / "app" / "routes" / "message_routes.py").read_text(encoding="utf-8")
    # 旧形式不应该存在
    bad1 = re.compile(r"if\s+cat_id\s+and\s+cat_id\s+in\s+visible_category_ids")
    bad2 = re.compile(r"if\s+not\s+cat_id\s+or\s+cat_id\s+not\s+in\s+visible_category_ids")
    assert not bad1.findall(src), "message_routes.py:449 区域还有旧形式 NULL-unsafe 检查"
    assert not bad2.findall(src), "message_routes.py:543 区域还有旧形式 NULL-unsafe 检查"


# ============================================================
# Step 8: ai_tools forum INNER JOIN 检查 (I1 follow-up)
# ============================================================

def test_ai_tools_forum_uses_outerjoin_for_null_safety():
    """ai_tools.py _list_my_forum_posts / _get_forum_post_detail 应用 outerjoin 不丢 NULL 帖"""
    src = AI_TOOLS.read_text(encoding="utf-8")
    # 检查 ForumCategory 相关 JOIN 都是 outerjoin 而非 join
    # 直接 grep: 不应该有 .join(models.ForumCategory, 的形式（应当全是 outerjoin）
    bad = re.compile(r"\.join\(\s*models\.ForumCategory")
    matches = bad.findall(src)
    assert not matches, (
        f"ai_tools.py 还有 {len(matches)} 处 .join(ForumCategory) — 应改 .outerjoin 否则 NULL 帖被过滤"
    )


# ============================================================
# Sanity: 所有改过的源文件都还能 ast.parse
# ============================================================

def test_modules_still_parse():
    for path in (FORUM_ROUTES, FORUM_DISCOVERY, FORUM_MY, FORUM_POSTS, AI_TOOLS):
        source = path.read_text(encoding="utf-8")
        ast.parse(source)
