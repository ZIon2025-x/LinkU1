#!/usr/bin/env bash
# Forum 体验优化 — deploy 后烟雾测试
#
# Verifies the core spec invariants from 2026-05-15 forum-category-and-replies
# implementation:
#   - NULL category 帖可创建, 出现在社区流 (Part 1)
#   - NULL category 帖不出现在某具体板块详情页 (Part 1)
#   - /posts/{id}/replies sort=hot / sort=time 都工作, 假 sort 422 (Part 2)
#   - 我的回复 / 我的收藏 列表里能看到 NULL category 帖关联条目 (C1 fix)
#
# Usage:
#   BASE_URL=https://linktest.up.railway.app \
#   SESSION_COOKIE='session_id=abc...; csrftoken=...' \
#   bash backend/scripts/forum_smoke_test.sh
#
# 获取 SESSION_COOKIE: 用真实账号登录 web/linktest, 从 DevTools → Application →
# Cookies copy 完整 cookie 字符串 (包含 session + csrf token, 见后端 secure_auth).
#
# ⚠️ Session 是 IP-bound (backend/app/secure_auth.py:776,789). 不要在 CI runner /
# 跟你浏览器不同 IP 的机器上跑 — 会 revoke 这个 session, 把自己挤下线。
# 在产生 cookie 的同一台机器/网络环境跑。
set -euo pipefail

BASE_URL="${BASE_URL:-https://linktest.up.railway.app}"
SESSION_COOKIE="${SESSION_COOKIE:?Set SESSION_COOKIE env var to a logged-in session cookie value}"
COOKIE_HEADER="Cookie: $SESSION_COOKIE"

echo "========================================="
echo "Forum 体验优化 烟雾测试"
echo "BASE_URL: $BASE_URL"
echo "========================================="

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Cleanup trap: 任何步骤失败也尝试删除 smoke 测试数据,避免污染 DB
POST_ID=""
cleanup() {
  if [ -n "$POST_ID" ]; then
    curl -sS -X DELETE "$BASE_URL/api/forum/posts/$POST_ID" -H "$COOKIE_HEADER" > /dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# === 1. 创建 NULL category 帖 ===
echo "1. 创建 NULL category 帖..."
CREATE_RESP=$(curl -sS -X POST "$BASE_URL/api/forum/posts" \
    -H "$COOKIE_HEADER" \
    -H "Content-Type: application/json" \
    -d '{"title":"Smoke test NULL category","content":"This post has no category at all. Created by smoke test script.","category_id":null}')
POST_ID=$(echo "$CREATE_RESP" | jq -r '.id // empty')
# 收紧检查: 必须既"有 category 字段"又"值为 null"; "字段缺失"或"非 null" 都算异常
CATEGORY_OK=$(echo "$CREATE_RESP" | jq 'has("category") and .category == null')

if [ -z "$POST_ID" ]; then
  fail "创建帖子失败: $CREATE_RESP"
fi
if [ "$CATEGORY_OK" != "true" ]; then
  fail "category 字段缺失或非 null: $(echo "$CREATE_RESP" | jq -c '.category // "<missing>"')"
fi
ok "创建 NULL category 帖 id=$POST_ID"

# === 2. NULL 帖出现在社区流 ===
echo "2. 验证 NULL 帖出现在 /api/forum/posts (社区流)..."
LIST_RESP=$(curl -sS "$BASE_URL/api/forum/posts?page=1&page_size=100" -H "$COOKIE_HEADER")
FOUND=$(echo "$LIST_RESP" | jq --arg pid "$POST_ID" '.posts | map(select(.id == ($pid | tonumber))) | length')
if [ "$FOUND" != "1" ]; then
  fail "NULL 帖未出现在社区流 (期待 1, 实际 $FOUND)"
fi
ok "NULL 帖在社区流可见"

# === 3. NULL 帖不出现在某具体板块详情页 ===
echo "3. 验证 NULL 帖不在 ?category_id=X 板块列表..."
# 任选一个 general / skill 类型 category id
CATS_RESP=$(curl -sS "$BASE_URL/api/forum/categories" -H "$COOKIE_HEADER")
# 响应是 ForumCategoryListResponse: {categories: [...]} — 用 .categories[] 而不是 .[]
SOME_CAT_ID=$(echo "$CATS_RESP" | jq -r '.categories[] | select(.type == "general" or .type == "skill") | .id' | head -1)
if [ -z "$SOME_CAT_ID" ]; then
  fail "找不到可用的 general/skill category"
fi

BOARD_RESP=$(curl -sS "$BASE_URL/api/forum/posts?category_id=$SOME_CAT_ID&page=1&page_size=100" -H "$COOKIE_HEADER")
NOT_FOUND=$(echo "$BOARD_RESP" | jq --arg pid "$POST_ID" '.posts | map(select(.id == ($pid | tonumber))) | length')
if [ "$NOT_FOUND" != "0" ]; then
  fail "NULL 帖意外出现在 category_id=$SOME_CAT_ID 板块"
fi
ok "NULL 帖不在板块 $SOME_CAT_ID 详情页 (预期)"

# === 4. get_replies sort=hot 返回 preview_children / total_children 结构 ===
echo "4. 验证 /posts/{id}/replies?sort=hot 响应结构..."
REPLIES_RESP=$(curl -sS "$BASE_URL/api/forum/posts/$POST_ID/replies?sort=hot" -H "$COOKIE_HEADER")
# 新帖没回复, replies 数组可能为空. 只验证响应顶层结构 OK.
TOTAL=$(echo "$REPLIES_RESP" | jq '.total // -1')
if [ "$TOTAL" = "-1" ]; then
  fail "/posts/$POST_ID/replies 响应缺少 .total 字段: $REPLIES_RESP"
fi
ok "/posts/$POST_ID/replies?sort=hot 响应结构 OK (total=$TOTAL)"

# === 5. sort=time 也工作 ===
echo "5. 验证 sort=time..."
TIME_RESP=$(curl -sS "$BASE_URL/api/forum/posts/$POST_ID/replies?sort=time" -H "$COOKIE_HEADER")
TIME_TOTAL=$(echo "$TIME_RESP" | jq '.total // -1')
if [ "$TIME_TOTAL" = "-1" ]; then
  fail "sort=time 响应缺 .total: $TIME_RESP"
fi
ok "sort=time 工作 OK"

# === 6. 假 sort 值应该 422 (回归: 防 Task 15 sort 值 bug) ===
echo "6. 验证 sort=invalid 返回 422..."
INVALID_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/api/forum/posts/$POST_ID/replies?sort=newest" -H "$COOKIE_HEADER")
if [ "$INVALID_CODE" != "422" ]; then
  fail "sort=newest 期待 422, 实际 $INVALID_CODE (回归: Task 15 sort 值 bug)"
fi
ok "sort=newest 正确返回 422"

# === 7. 我的回复包含 NULL 帖关联回复 (验 C1 修复) ===
echo "7a. 在 NULL 帖里发条回复..."
REPLY_RESP=$(curl -sS -X POST "$BASE_URL/api/forum/posts/$POST_ID/replies" \
    -H "$COOKIE_HEADER" \
    -H "Content-Type: application/json" \
    -d '{"content":"Smoke test reply to NULL category post"}')
REPLY_ID=$(echo "$REPLY_RESP" | jq -r '.id // empty')
if [ -z "$REPLY_ID" ]; then
  fail "回复 NULL 帖失败: $REPLY_RESP"
fi
ok "回复 id=$REPLY_ID 创建"

echo "7b. 验证 /forum/my/replies 包含这条 reply..."
MY_REPLIES_RESP=$(curl -sS "$BASE_URL/api/forum/my/replies?page=1&page_size=50" -H "$COOKIE_HEADER")
MY_REPLY_FOUND=$(echo "$MY_REPLIES_RESP" | jq --arg rid "$REPLY_ID" '.replies | map(select(.id == ($rid | tonumber))) | length')
if [ "$MY_REPLY_FOUND" != "1" ]; then
  fail "我的回复里看不到 NULL 帖关联的 reply $REPLY_ID (验 C1 修复)"
fi
ok "我的回复包含 NULL 帖关联 reply (验 C1 修复)"

# === 8. 收藏 NULL 帖, 验证收藏列表能看到 ===
echo "8a. 收藏 NULL 帖..."
# POST /api/forum/favorites with body {post_id: X} — toggle 接口
# 捕获 http_code, 2xx 才算 OK; 不再用 '|| true' 静默吞错
FAV_CODE=$(curl -sS -o /tmp/fav_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/forum/favorites" \
    -H "$COOKIE_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"post_id\":$POST_ID}")
if [ "$FAV_CODE" -lt 200 ] || [ "$FAV_CODE" -ge 300 ]; then
  fail "收藏 POST 失败: HTTP $FAV_CODE, body: $(cat /tmp/fav_resp.json 2>/dev/null)"
fi
ok "已收藏 (HTTP $FAV_CODE)"

echo "8b. 验证 /forum/my/favorites 包含..."
MY_FAVS_RESP=$(curl -sS "$BASE_URL/api/forum/my/favorites?page=1&page_size=50" -H "$COOKIE_HEADER")
FAV_FOUND=$(echo "$MY_FAVS_RESP" | jq --arg pid "$POST_ID" '.favorites | map(select(.post.id == ($pid | tonumber))) | length')
if [ "$FAV_FOUND" != "1" ]; then
  fail "我的收藏里看不到 NULL 帖 $POST_ID (验 C1 修复)"
fi
ok "我的收藏包含 NULL 帖 (验 C1 修复)"

# === 9. 清理 (由 EXIT trap 处理, 任何失败也会跑) ===
echo "9. 清理测试数据 (EXIT trap 已注册)..."
ok "smoke test post $POST_ID 将由 trap 删除"

echo ""
echo "========================================="
echo -e "${GREEN}✓ 全部 smoke 测试通过${NC}"
echo "========================================="
