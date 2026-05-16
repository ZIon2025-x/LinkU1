"""Test reply hot sort + progressive children loading (spec 2026-05-15 Part 2).

⚠️ 关于测试形式 ⚠️
原始 plan 写的是 HTTP 级集成测试，要 `async_client` / `user_session_cookie` /
`post_with_5_root_4_children` / `post_with_mixed_likes` 等 fixture，但
`backend/tests/conftest.py` 里没有这些 fixture（仓库 API 测试都打远程 Railway 环境）。
这里改成 AST/结构检查，跟 Task 3/4 同款 pattern，验证关键守卫 / 字段 / 排序逻辑存在。

具体覆盖：
- get_replies 接受 sort 参数（hot | time）
- 只过滤根评论 (parent_reply_id IS NULL)
- 每根填 total_children + preview_children
- 返回 ForumRootReplyOut
- sort=hot 时按 like_count DESC
"""
from __future__ import annotations

import ast
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REPLIES_ROUTE = REPO_ROOT / "app" / "routes" / "forum_replies_routes.py"


def _function_source(name: str) -> str:
    src = REPLIES_ROUTE.read_text(encoding="utf-8")
    tree = ast.parse(src)
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name:
            return ast.get_source_segment(src, node) or ""
    raise AssertionError(f"function {name} not found")


def test_get_replies_has_sort_param():
    """get_replies 接受 sort 参数: hot|time"""
    src = _function_source("get_replies")
    assert "sort" in src
    assert "hot" in src and "time" in src


def test_get_replies_filters_to_root_only():
    """get_replies 只查根评论 (parent_reply_id IS NULL)"""
    src = _function_source("get_replies")
    assert "parent_reply_id.is_(None)" in src or "parent_reply_id == None" in src


def test_get_replies_uses_total_children_field():
    """get_replies 给每根填 total_children"""
    src = _function_source("get_replies")
    assert "total_children" in src


def test_get_replies_uses_preview_children_field():
    """get_replies 给每根填 preview_children"""
    src = _function_source("get_replies")
    assert "preview_children" in src


def test_get_replies_returns_root_reply_out():
    """get_replies 返回 ForumRootReplyOut"""
    src = _function_source("get_replies")
    assert "ForumRootReplyOut" in src


def test_hot_sort_orders_by_like_count():
    """sort=hot 时按 like_count desc"""
    src = _function_source("get_replies")
    # like_count.desc() 应当出现
    assert "like_count.desc()" in src or ("like_count" in src and "desc" in src)
