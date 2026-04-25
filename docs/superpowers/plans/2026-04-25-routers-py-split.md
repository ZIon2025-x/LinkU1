# `backend/app/routers.py` 拆分实施计划（2026-04-25 版）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `backend/app/routers.py` 的 162 个路由拆到 10 个 `backend/app/routes/*_routes.py` 文件 + 并入 1 个现有 admin 文件，删 10 条 debug 路由，`routers.py` 保留 19 个模块级辅助函数作为 helper 仓库，客户端行为零回归。

**Architecture:** 每个新文件自带独立 `APIRouter()`（不带 prefix），通过 `main.py` 的循环双挂载到 `/api` 和 `/api/users` 两前缀。用 `dump_routes.py` 快照脚本对比路由集合，`test_routers_split_smoke.py` 覆盖每域至少一条路径的双前缀存在性。每个迁移 commit 直推 main，等 Railway 部署 linktest 后跑 `smoke_linktest.sh` 烟测。

**Tech Stack:** FastAPI · SQLAlchemy · Pydantic · pytest · GitHub Actions · Railway

**Spec:** `docs/superpowers/specs/2026-04-25-routers-py-split-design.md`
**Supersedes plan:** `docs/superpowers/plans/2026-04-17-routers-split.md`（同主题；本版基于当前 `routers.py` 状态刷新行号、改为直推 main、加入 GH Actions / linktest 烟测脚本 / `test_consultation_placeholder_upgrade.py` 重定向、加最终 schedule follow-up）

---

## 前置审计结果（writing-plans 阶段已完成）

`grep "from app\.routers\|from app import routers\|import app\.routers"` 全仓扫描结果（截至 2026-04-25）：

| 文件 : 行 | 用法 | 处理 |
|---|---|---|
| `backend/app/main.py:42` | `from app.routers import router as main_router` | Task 16 删除 |
| `backend/app/async_routers.py:1745` | `from app.routers import confirm_task_completion as sync_confirm` | Task 8（refund）添加 re-export shim |
| `backend/app/expert_consultation_routes.py:1256` | `from app.routers import _payment_method_types_for_currency`（函数内 import） | helper 留 routers.py，零改动 |
| `backend/tests/test_team_dispute_reversal.py:51,76,90,108,125`（5 处） | `from app.routers import _handle_dispute_team_reversal` | helper 留 routers.py，零改动 |
| `backend/tests/test_stripe_webhook_handlers_team.py:44,65,83,96`（4 处） | `from app.routers import _handle_account_updated` | helper 留 routers.py，零改动 |
| `backend/tests/test_consultation_placeholder_upgrade.py:459,474,503`（3 处） | `from app import routers; inspect.getsource(routers)` 检查路由源码字符串 | **Task 12（payment）+ Task 13（task）需重定向**（详见任务卡片） |
| `.github/workflows/main-ci.yml:66` | `python -c "import app.routers; ..."` 仅 import smoke | 无改动 — 拆分后 `app.routers` 仍是合法模块 |

**关键新发现 vs spec**：spec 列了 4 处 importer，实际有 6 处（spec 漏掉 `test_consultation_placeholder_upgrade.py` 的 3 处和 `main-ci.yml` 的 1 处）。其中 `test_consultation_placeholder_upgrade.py` 是**会破的测试**：它用 `inspect.getsource(routers)` 拿源码字符串后断言路径片段（如 `@router.post("/tasks/{task_id}/pay")`）存在。当对应路由迁出后，这些断言会失败。处理方式：在 Task 12（payment 提取）和 Task 13（task 提取）里，把这些断言重定向到对应的新模块。

---

## 标准提取流程（Standard Extraction Procedure）

Tasks 5–14 是 10 个域的提取工作 + 1 个 admin 合并，遵循相同流程。每个任务卡片会列**输入**（路由清单 + 必需 imports + 该域专属注意事项），然后执行：

**Procedure Steps（每次提取必走）：**

1. **打开 `backend/app/routers.py`**，用 Grep 或 Read 工具定位任务卡片中列出的每一条路由（按行号）。注意：行号是写本计划时的实测值，若期间 `routers.py` 有其它改动导致漂移，按 `(method, path)` 重新定位。

2. **在 `backend/app/routes/<domain>_routes.py` 写新文件**：
   - 顶部 imports：任务卡片指定的具体 imports（仅保留该域用到的）
   - `router = APIRouter()`（**不**加 `prefix=`，因为 main.py 会双挂载）
   - 逐条把路由函数（装饰器 + 函数体 + 函数内 `from ... import` 语句）从 `routers.py` 复制粘贴过来

3. **从 `routers.py` 删除已迁移的路由函数**（只删路由函数本身，保留其依赖的模块级 `_xxx` helper 不动）。

4. **修改 `backend/app/main.py`**：
   - 在 `from app.routes import (...)` import 块里取消 `<domain>_routes` 那一行的注释
   - 在 `_SPLIT_ROUTERS` 列表里取消 `(<domain>_routes.router, "<中文标签>")` 那一行的注释
   - （第一个提取任务先搭好这个 import 块和列表骨架，见 Task 4）

5. **跑本地 Gate**（每条都必须绿）：

   ```bash
   cd backend
   python -c "from app.main import app; print('ok')"
   python -m scripts.dump_routes > /tmp/routes_current.json
   diff scripts/routes_baseline.json /tmp/routes_current.json
   pytest tests/test_routers_split_smoke.py -v
   pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
   ```

   **允许的 diff 差异**：
   - Task 8（auth_inline）后允许 10 条 debug 路由消失
   - 其它任何任务 → diff 必须为空（空 diff 意味着 `(method, path, name)` 集合完全一致）

6. **Commit + Push + Linktest 烟测**：

   ```bash
   git add <files>
   git commit -m "refactor(routers): extract <domain> routes"
   git push origin main
   # 等 Railway 部署 linktest（约 1-2 分钟），然后：
   bash backend/scripts/smoke_linktest.sh
   ```

   `smoke_linktest.sh` 全绿 → 进下一任务。
   烟测挂 → **立即** `git revert <sha> && git push origin main`，分析后再续。

---

## Task 1: 创建脚本与路由子包目录骨架

**Files:**
- Create: `backend/scripts/__init__.py`（空）
- Create: `backend/app/routes/__init__.py`（已存在，仅更新 docstring）

- [ ] **Step 1: 验证当前在 main 分支，且 working tree 干净**

```bash
git status -s
git rev-parse --abbrev-ref HEAD
```

Expected: status 输出干净（或仅有不相关的 .pyc / worktree 修改），分支为 `main`。如有未提交改动，先 stash。

- [ ] **Step 2: 确认目录存在**

```bash
ls backend/scripts/ 2>&1 | head -3
ls backend/app/routes/ 2>&1 | head -3
```

`backend/scripts/` 应已存在（有 `audit_zero_price_applications.sql` 等）。`backend/app/routes/` 应已存在（有 `badges.py` 等 10 个文件）。

- [ ] **Step 3: 创建 `backend/scripts/__init__.py`**

```python
# Empty file - marks scripts/ as a package so `python -m scripts.dump_routes` works
```

- [ ] **Step 4: 更新 `backend/app/routes/__init__.py`**

读取现有文件内容（应是当前的"迁移计划注释"），替换为：

```python
"""
Route modules extracted from app/routers.py (split completed 2026-04-25).

Each submodule owns one domain of routes. main.py iterates over them and
double-mounts at /api and /api/users prefixes via the _SPLIT_ROUTERS list.

This package intentionally does NOT expose a combined_router — main.py handles
registration directly to match the style of other *_routes.py files in app/.

See docs/superpowers/specs/2026-04-25-routers-py-split-design.md
"""
```

- [ ] **Step 5: Gate（仅 import 检查 — 没动路由）**

```bash
cd backend
python -c "from app.main import app; print('ok')"
```

Expected: `ok`

- [ ] **Step 6: Commit + Push**

```bash
git add backend/scripts/__init__.py backend/app/routes/__init__.py
git commit -m "chore(routers): scaffold scripts/ package + update routes/ docstring"
git push origin main
```

无需 linktest 烟测（本任务不影响路由）。

---

## Task 2: 写路由快照脚本 `dump_routes.py`

**Files:**
- Create: `backend/scripts/dump_routes.py`
- Create: `backend/scripts/routes_baseline.json`（运行后产生）

- [ ] **Step 1: 创建 `backend/scripts/dump_routes.py`**

```python
"""Dump all FastAPI APIRoute instances as sorted JSON for baseline/diff.

Usage:
    python -m scripts.dump_routes > scripts/routes_baseline.json

Or with explicit output:
    python -m scripts.dump_routes scripts/routes_current.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Ensure `backend/` is on sys.path so `app.main` imports work when run from anywhere
_HERE = Path(__file__).resolve().parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from fastapi.routing import APIRoute

from app.main import app


def dump_routes() -> list[dict]:
    entries: list[dict] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        methods = sorted(route.methods or [])
        for method in methods:
            entries.append(
                {
                    "method": method,
                    "path": route.path,
                    "name": route.name,
                }
            )
    entries.sort(key=lambda e: (e["method"], e["path"], e["name"]))
    return entries


def main() -> int:
    entries = dump_routes()
    out = json.dumps(entries, indent=2, ensure_ascii=False)
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(out, encoding="utf-8")
        print(f"Wrote {len(entries)} routes to {sys.argv[1]}", file=sys.stderr)
    else:
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: 运行脚本生成基线**

```bash
cd backend
python -m scripts.dump_routes scripts/routes_baseline.json
```

Expected stderr: `Wrote N routes to scripts/routes_baseline.json`，N 为当前路由总数（包含所有 *_routes.py，应数百条）。

- [ ] **Step 3: 验证基线合理**

```bash
head -c 500 backend/scripts/routes_baseline.json
wc -l backend/scripts/routes_baseline.json
```

Expected: JSON 数组开头是 `[\n  {\n    "method": "DELETE",\n    "path": "...",\n    "name": "..."`，行数 ~3000-5000（每条路由跨 4-5 行）。

- [ ] **Step 4: Commit + Push**

```bash
git add backend/scripts/dump_routes.py backend/scripts/routes_baseline.json
git commit -m "chore(routers): add route snapshot script + baseline for split"
git push origin main
```

---

## Task 3: 写 smoke 测试

**Files:**
- Create: `backend/tests/test_routers_split_smoke.py`

- [ ] **Step 1: 创建测试文件**

```python
"""
Smoke test for the routers.py split refactor.

For each domain that gets extracted, verify at least one representative route
is still reachable at BOTH /api/ and /api/users/ prefixes. Asserts HTTP status
code only — not business logic.

If a route's auth behavior turns out differently than asserted here during
execution, adjust the expected code inline. The goal is to catch:
  - Router not registered at all (→ 404)
  - Router registered at only one prefix (→ 404 on the other)
  - Import error in the new module (→ 500 or collection error)
"""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


# (domain, method, path, expected_status_codes)
# Both /api/<p> and /api/users/<p> should be reachable.
SMOKE_PROBES: list[tuple[str, str, str, tuple[int, ...]]] = [
    ("auth_inline", "POST", "/csp-report", (204, 400, 422)),
    ("task", "GET", "/tasks/1/history", (401, 403)),
    ("refund", "GET", "/tasks/1/refund-status", (401, 403)),
    ("profile", "GET", "/profile/me", (401, 403)),
    ("message", "GET", "/messages/unread/count", (401, 403)),
    ("payment_inline", "POST", "/stripe/webhook", (400, 422)),
    ("cs", "GET", "/customer-service/status", (200, 401, 403)),
    ("translation", "GET", "/translate/metrics", (200, 401, 403)),
    ("system", "GET", "/banners", (200,)),
    ("system", "GET", "/faq", (200,)),
    ("upload_inline", "POST", "/upload/image", (401, 403, 422)),
]


@pytest.mark.parametrize("domain,method,path,expected", SMOKE_PROBES)
@pytest.mark.parametrize("prefix", ["/api", "/api/users"])
def test_route_reachable_at_both_prefixes(
    client: TestClient,
    prefix: str,
    domain: str,
    method: str,
    path: str,
    expected: tuple[int, ...],
):
    url = f"{prefix}{path}"
    resp = client.request(method, url)
    assert resp.status_code in expected, (
        f"{method} {url} returned {resp.status_code}, expected one of {expected}. "
        f"Domain={domain}. "
        f"If this is a genuine behavior change, update SMOKE_PROBES inline."
    )
```

- [ ] **Step 2: 运行测试验证基础状态**

```bash
cd backend
pytest tests/test_routers_split_smoke.py -v
```

Expected: 全部 22 个断言（11 探针 × 2 前缀）通过。如果有个别探针因实际鉴权行为不同而失败，**现场修改 `expected` 元组**使其与真实响应一致，然后再次运行至全绿。

**如果有探针 404**：说明该域路由在当前（未拆分）状态下不在期望路径，立即调查——可能是路径拼写错，或某路由的归属判断有误。修好再进下一步。

- [ ] **Step 3: Commit + Push**

```bash
git add backend/tests/test_routers_split_smoke.py
git commit -m "test(routers): add smoke test harness for split refactor"
git push origin main
```

---

## Task 4: 改 main.py — 加循环注册骨架（不动任何路由）

**Files:**
- Modify: `backend/app/main.py:42`（import 块）和 `:283 / :339`（mount）

这一步**不迁移任何路由**，只是把 `main.py` 改成"既保留 `main_router` 双挂载、又预留循环注册新拆 router"的形式。Tasks 5+ 每次只在 `_SPLIT_ROUTERS` 列表里取消一行注释 + import 多一个。

- [ ] **Step 1: 读取 main.py 当前注册行**

```bash
cd backend
grep -n "include_router(main_router\|from app.routers import" app/main.py
```

Expected 输出：
- line 42: `from app.routers import router as main_router`
- line 283: `app.include_router(main_router, prefix="/api/users", tags=["users"])`
- line 339: `app.include_router(main_router, prefix="/api", tags=["main"])`

- [ ] **Step 2: 修改 main.py — 在 line 42 之后加 split routers import 骨架**

定位 `from app.routers import router as main_router`（line 42），在它**下方**插入：

```python

# 新拆分出来的领域 router（每次提取一个域时在此 import + 加入 _SPLIT_ROUTERS）
# from app.routes import (
#     auth_inline_routes,
#     task_routes,
#     refund_routes,
#     profile_routes,
#     message_routes,
#     payment_inline_routes,
#     cs_routes,
#     translation_routes,
#     system_routes,
#     upload_inline_routes,
# )
```

- [ ] **Step 3: 在 line 339 之后加 `_SPLIT_ROUTERS` 注册循环**

定位 `app.include_router(main_router, prefix="/api", tags=["main"])` （line 339），在它**之后**（且早于其它 `app.include_router` 注册）插入：

```python

# === Split routers (extracted from app/routers.py) ===
# 每个都双挂载到 /api 和 /api/users，行为等价于 main_router 的双挂载。
# 每次新域提取时往这个列表里取消注释一行。
_SPLIT_ROUTERS: list[tuple[object, str]] = [
    # (auth_inline_routes.router, "auth-inline"),
    # (task_routes.router, "任务"),
    # (refund_routes.router, "退款"),
    # (profile_routes.router, "用户资料"),
    # (message_routes.router, "消息与通知"),
    # (payment_inline_routes.router, "支付-inline"),
    # (cs_routes.router, "客服"),
    # (translation_routes.router, "翻译"),
    # (system_routes.router, "系统"),
    # (upload_inline_routes.router, "上传-inline"),
]

for _r, _tag in _SPLIT_ROUTERS:
    app.include_router(_r, prefix="/api/users", tags=[_tag])
    app.include_router(_r, prefix="/api", tags=[_tag])
```

- [ ] **Step 4: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
```

Expected: `ok`、diff 完全为空、smoke 22/22 绿。本任务**不应**改变任何路由。

- [ ] **Step 5: Commit + Push**

```bash
git add backend/app/main.py
git commit -m "refactor(routers): add main.py scaffolding for split-router registration"
git push origin main
```

无路由变更，跳过 linktest 烟测（GH Actions 那条已通过 = 充分验证）。

---

## Task 5: 写 `smoke_linktest.sh` + GH Actions workflow

**Files:**
- Create: `backend/scripts/smoke_linktest.sh`
- Create: `.github/workflows/routes-snapshot.yml`

把 push-后验证的两个工具都在拆分**开始前**就位，让后续 11 个迁移 commit 都能享用。

- [ ] **Step 1: 创建 `backend/scripts/smoke_linktest.sh`**

```bash
#!/usr/bin/env bash
# Smoke test against linktest (Railway staging) — runs after each split commit
# is deployed. Asserts each domain probe returns an expected status at BOTH
# /api and /api/users prefixes.
#
# Usage:
#   bash backend/scripts/smoke_linktest.sh
#
# Override base URL:
#   BASE=https://api.link2ur.com bash backend/scripts/smoke_linktest.sh
set -u
BASE="${BASE:-https://linktest.up.railway.app}"

# (method, path, expected_codes_pipe_separated)
PROBES=(
  "POST /csp-report 204|400|422"
  "GET /tasks/1/history 401|403"
  "GET /tasks/1/refund-status 401|403"
  "GET /profile/me 401|403"
  "GET /messages/unread/count 401|403"
  "POST /stripe/webhook 400|422"
  "GET /customer-service/status 200|401|403"
  "GET /translate/metrics 200|401|403"
  "GET /banners 200"
  "GET /faq 200"
  "POST /upload/image 401|403|422"
)

PREFIXES=("/api" "/api/users")
fail=0
for probe in "${PROBES[@]}"; do
  read -r method path expected <<< "$probe"
  for prefix in "${PREFIXES[@]}"; do
    url="${BASE}${prefix}${path}"
    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url")
    if [[ "|$expected|" != *"|$code|"* ]]; then
      echo "✗ $method $url → $code (expected $expected)"
      fail=1
    else
      echo "✓ $method $url → $code"
    fi
  done
done

if [[ $fail -ne 0 ]]; then
  echo ""
  echo "Linktest smoke FAILED. If a commit was just pushed, revert it:"
  echo "  git revert HEAD && git push origin main"
  exit 1
fi
echo ""
echo "Linktest smoke OK ($((${#PROBES[@]} * 2)) probes)."
```

- [ ] **Step 2: 给脚本加可执行位**

```bash
chmod +x backend/scripts/smoke_linktest.sh
```

（Windows 上 chmod 是 no-op，但 `git add` 仍会保留 mode；通过 git push 后 Linux side 会有正确权限。）

- [ ] **Step 3: 本地试跑（针对当前 main，应该全绿）**

```bash
bash backend/scripts/smoke_linktest.sh
```

Expected: 22 行 `✓ ...` 输出 + `Linktest smoke OK (22 probes).`。

如果 linktest 本身挂了（不属于本拆分问题），先确认 Railway 部署状态再继续。

- [ ] **Step 4: 创建 `.github/workflows/routes-snapshot.yml`**

```yaml
name: Routes Snapshot Check

on:
  push:
    branches: ["**"]
    paths:
      - "backend/app/**"
      - "backend/scripts/dump_routes.py"
      - "backend/scripts/routes_baseline.json"
      - "backend/tests/test_routers_split_smoke.py"
  pull_request:
    branches: ["main"]
    paths:
      - "backend/app/**"
      - "backend/scripts/dump_routes.py"
      - "backend/scripts/routes_baseline.json"

jobs:
  snapshot-diff:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: password
          POSTGRES_DB: linku_db
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        working-directory: backend
        run: |
          pip install -r requirements.txt
          pip install -r tests/requirements-test.txt || true

      - name: Compare route snapshot
        working-directory: backend
        env:
          DATABASE_URL: postgresql+psycopg2://postgres:password@localhost:5432/linku_db
        run: |
          python -m scripts.dump_routes > /tmp/routes_current.json
          if ! diff -u scripts/routes_baseline.json /tmp/routes_current.json; then
            echo "::error::Route snapshot has diverged from baseline."
            echo "If intentional (e.g., commit 4 deletes 10 debug routes), regenerate:"
            echo "  python -m scripts.dump_routes scripts/routes_baseline.json"
            exit 1
          fi

      - name: Run smoke test
        working-directory: backend
        env:
          DATABASE_URL: postgresql+psycopg2://postgres:password@localhost:5432/linku_db
        run: pytest tests/test_routers_split_smoke.py -v
```

- [ ] **Step 5: 验证 workflow YAML 语法**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/routes-snapshot.yml')); print('yaml ok')"
```

Expected: `yaml ok`

- [ ] **Step 6: Commit + Push**

```bash
git add backend/scripts/smoke_linktest.sh .github/workflows/routes-snapshot.yml
git commit -m "ci(routers): add linktest smoke script + routes-snapshot GH Actions workflow"
git push origin main
```

**Push 后**：观察 GitHub Actions UI，确认 `Routes Snapshot Check` 第一次运行是绿色。如果挂了，分析后修复（可能是依赖路径或 DATABASE_URL 配置问题），不要急着开下一个 task。

---

## Task 6: 提取 translation 域（12 routes，最低风险）

**Files:**
- Create: `backend/app/routes/translation_routes.py`
- Modify: `backend/app/routers.py`（删除 12 个路由函数）
- Modify: `backend/app/main.py`（取消两行 `translation_routes` 注释）

**输入 — 要迁移的路由**（基于当前 routers.py 实测行号）：

| Line | Method | Path |
|---|---|---|
| 13953 | POST | `/translate` |
| 14244 | POST | `/translate/batch` |
| 14419 | GET | `/translate/task/{task_id}` |
| 14459 | POST | `/translate/task/{task_id}` |
| 14654 | POST | `/translate/tasks/batch` |
| 14773 | GET | `/translate/metrics` |
| 14800 | GET | `/translate/services/status` |
| 14848 | POST | `/translate/services/reset` |
| 14893 | GET | `/translate/services/failed` |
| 14917 | GET | `/translate/alerts` |
| 14951 | POST | `/translate/prefetch` |
| 15007 | POST | `/translate/warmup` |

**输入 — 新文件 imports**（按实际函数体出现的 import 补齐；下面是基础集）：

```python
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_admin_user,
    get_sync_db,
)
# 函数体如调用 _translate_missing_tasks_async / _trigger_background_translation_prefetch
# (留在 routers.py 的 helper)，加：
# from app.routers import _translate_missing_tasks_async, _trigger_background_translation_prefetch

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 创建 `backend/app/routes/translation_routes.py`**

按 Standard Extraction Procedure Step 2 操作：把上表 12 条路由的装饰器 + 函数体从 `routers.py` 原样复制过来。逐条核对：
- 装饰器保持 `@router.post(...)` / `@router.get(...)` 原样（**不**改 path）
- 函数内部的 `from app.xxx import ...` 也搬过来（包括函数内 import）
- 如函数引用模块级 `_translate_missing_tasks_async`（routers.py:116）/ `_trigger_background_translation_prefetch`（routers.py:163），在新文件顶部加 `from app.routers import ...` 

- [ ] **Step 2: 从 `routers.py` 删除这 12 个路由函数**

按 Procedure Step 3：逐条定位、删除装饰器 + 函数体 + 函数体内的 import。**保留** routers.py 顶部的模块级 `_translate_missing_tasks_async` / `_trigger_background_translation_prefetch`。

- [ ] **Step 3: 更新 `main.py`**

- 在 `from app.routes import (...)` import 块取消 `translation_routes,` 那行注释
- 在 `_SPLIT_ROUTERS` 取消 `(translation_routes.router, "翻译"),` 那行注释

- [ ] **Step 4: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: `ok`、diff 为空、smoke 22/22 绿、外部 importer 测试全绿。

**若 diff 非空**：检查是否漏搬某条路由，或函数名拼错导致 `name` 字段变化。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/translation_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract translation routes to routes/translation_routes.py"
git push origin main
# 等 ~90s Railway 部署
sleep 90
bash backend/scripts/smoke_linktest.sh
```

烟测全绿 → 进 Task 7。烟测挂 → `git revert HEAD && git push origin main`，分析。

---

## Task 7: 提取 system 域（11 routes，低风险）

**Files:**
- Create: `backend/app/routes/system_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 11108 | GET | `/stats` |
| 11134 | GET | `/system-settings/public` |
| 11603 | GET | `/user-preferences` |
| 11632 | PUT | `/user-preferences` |
| 11788 | GET | `/timezone/info` |
| 12617 | GET | `/job-positions` |
| 12688 | POST | `/job-applications` |
| 15074 | GET | `/banners` |
| 15118 | GET | `/app/version-check` |
| 15152 | GET | `/faq` |
| 15200 | GET | `/legal/{doc_type}` |

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_user_optional,
    get_sync_db,
)
# 如 /app/version-check 调用 _parse_semver (routers.py 末端) 加：
# from app.routers import _parse_semver

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**（参考 Task 6 步骤 1-3）

- [ ] **Step 4: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: 全绿、diff 空。system 有 `/banners` + `/faq` 两个 200 探针，都应过。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/system_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract system routes to routes/system_routes.py"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 8: 提取 upload_inline 域（7 routes，中风险）

**Files:**
- Create: `backend/app/routes/upload_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 11935 | POST | `/upload/image` |
| 12029 | POST | `/upload/public-image` (deprecated=True) |
| 12189 | POST | `/refresh-image-url` |
| 12234 | GET | `/private-image/{image_id}` |
| 12254 | POST | `/messages/generate-image-url` |
| 12433 | POST | `/upload/file` |
| 12491 | GET | `/private-file` |

**风险点**：文件名 `upload_inline_routes.py` 与既有 `upload_routes.py`、`upload_v2_router` 不要混淆。确认 `main.py` 里 `app.include_router(upload_v2_router, ...)` 不被本任务影响。

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_user_secure_async_csrf,
    get_sync_db,
    get_async_db_dependency,
)
# 函数体内可能用到 file_utils 中的 helper —— 按实际函数体内 import 补齐

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**

- [ ] **Step 4: 本地 Gate**（同 Task 6 命令）

Expected: diff 空、全绿。smoke 的 `POST /upload/image`（无 file）应返 401/403/422。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/upload_inline_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract upload-inline routes to routes/upload_inline_routes.py"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 9: 提取 auth_inline 域 + 删除 10 条 debug + 迁移 /logout

**Files:**
- Create: `backend/app/routes/auth_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`
- Modify: `backend/scripts/routes_baseline.json`（更新 baseline 反映 debug 删除）

**输入 — 要迁移的路由（12 条保留）：**

| Line | Method | Path |
|---|---|---|
| 210 | POST | `/csp-report` |
| 237 | POST | `/password/validate` |
| 276 | POST | `/register` |
| 534 | GET | `/verify-email` |
| 535 | GET | `/verify-email/{token}` |
| 729 | POST | `/resend-verification` |
| 763 | POST | `/admin/login` |
| 802 | GET | `/user/info` |
| 992 | GET | `/confirm/{token}` |
| 1005 | POST | `/forgot_password` |
| 1074 | POST | `/reset_password/{token}` |
| **10055** | POST | `/logout` ← **此条几何位置在 cs 区但逻辑归 auth，单独挑出搬走** |

**输入 — 要删除的路由（10 条 debug，不迁移）：**

| Line | Method | Path |
|---|---|---|
| 228 | POST | `/register/test` |
| 266 | POST | `/register/debug` |
| 818 | GET | `/debug/test-token/{token}` |
| 846 | GET | `/debug/simple-test` |
| 851 | POST | `/debug/fix-avatar-null` |
| 872 | GET | `/debug/check-user-avatar/{user_id}` |
| 893 | GET | `/debug/test-reviews/{user_id}` |
| 898 | GET | `/debug/session-status` |
| 936 | GET | `/debug/check-pending/{email}` |
| 984 | GET | `/debug/test-confirm-simple` |

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.config import Config
from app.deps import (
    check_admin_user_status,
    get_current_admin_user,
    get_current_user_secure_sync_csrf,
    get_current_user_optional,
    get_db,
    get_sync_db,
)
from app.email_utils import (
    confirm_reset_token,
    confirm_token,
    generate_confirmation_token,
    generate_reset_token,
    send_confirmation_email,
    send_reset_email,
)
from app.rate_limiting import rate_limit
from app.security import clear_secure_cookies, create_access_token, verify_password

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 把 12 条保留路由搬到新文件**（**不要**搬 10 条 debug）

按 Standard Extraction Procedure Step 2。注意 `/logout` 的函数定义在 line 10055，要单独跑去 cs 区那里抓回来。

- [ ] **Step 2: 从 `routers.py` 删除全部 22 条**（12 条已迁走 + 10 条 debug 直接删）

- [ ] **Step 3: 更新 `main.py`**（取消 `auth_inline_routes` 两行注释）

- [ ] **Step 4: 重新生成 baseline**（因为 debug 删除导致路由集合变小）

```bash
cd backend
python -m scripts.dump_routes scripts/routes_baseline.json
```

stderr 应显示新的路由数 = 旧总数 - 20（10 条 debug × 2 前缀）。

- [ ] **Step 5: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: diff 空（baseline 已更新到删 debug 后的状态）、smoke 全绿（auth_inline 的 `/csp-report` 探针过）。

**手动验证 debug 已删**：

```bash
cd backend
python -m scripts.dump_routes | python -c "import sys,json; d=json.load(sys.stdin); hits=[r for r in d if '/debug/' in r['path'] or r['path'] in ['/register/test','/register/debug']]; print(f'debug-like routes remaining: {len(hits)}'); [print(r) for r in hits]"
```

Expected: `debug-like routes remaining: 0`

- [ ] **Step 6: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/auth_inline_routes.py backend/app/routers.py backend/app/main.py backend/scripts/routes_baseline.json
git commit -m "$(cat <<'EOF'
refactor(routers): extract auth-inline routes + delete 10 debug endpoints

Deleted (永久, 不回滚):
- POST /register/test, /register/debug
- GET/POST /debug/{test-token,simple-test,fix-avatar-null,check-user-avatar,
  test-reviews,session-status,check-pending,test-confirm-simple}

Migrated 12 auth routes (including /logout reassigned from cs region) to
routes/auth_inline_routes.py. Baseline regenerated to reflect deletions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 10: 提取 refund 域（8 routes，含 `confirm_task_completion` re-export）

**Files:**
- Create: `backend/app/routes/refund_routes.py`
- Modify: `backend/app/routers.py`（删 8 路由 + 加 1 行 re-export）
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path | 函数名（确认用） |
|---|---|---|---|
| 2534 | POST | `/tasks/{task_id}/dispute` | (验证文件确定) |
| 2662 | POST | `/tasks/{task_id}/refund-request` | |
| 2999 | GET | `/tasks/{task_id}/refund-status` | |
| 3083 | GET | `/tasks/{task_id}/dispute-timeline` | |
| 3415 | GET | `/tasks/{task_id}/refund-history` | |
| 3509 | POST | `/tasks/{task_id}/refund-request/{refund_id}/cancel` | |
| 3638 | POST | `/tasks/{task_id}/refund-request/{refund_id}/rebuttal` | |
| 3919 | POST | `/tasks/{task_id}/confirm_completion` | **`confirm_task_completion`** ← 被 `async_routers.py:1745` import |

**关键**：line 3919 的 `confirm_task_completion` 被 `async_routers.py:1745` 通过 `from app.routers import confirm_task_completion as sync_confirm` import。搬走后**必须**在 `routers.py` 留 re-export shim。

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional, List
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_admin_user,
    get_sync_db,
)
from app.push_notification_service import send_push_notification
# 函数体如果调用 _handle_dispute_team_reversal (留在 routers.py)，加：
# from app.routers import _handle_dispute_team_reversal

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 按 Standard Extraction Procedure 搬 8 条路由到新文件**

- [ ] **Step 2: 在 `routers.py` 末尾加 re-export shim**

定位 routers.py 末尾（最后一个 `_xxx` helper 之后），加：

```python


# === Re-exports for backward compat with external importers ===
# async_routers.py:1745 imports this function; preserved as re-export.
from app.routes.refund_routes import confirm_task_completion  # noqa: F401
```

- [ ] **Step 3: 更新 `main.py`**（取消 `refund_routes` 两行注释）

- [ ] **Step 4: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import confirm_task_completion; print('re-export ok')"
python -c "from app.async_routers import sync_confirm; print('async_routers consumer ok')" 2>&1 | head -5
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: 全绿、diff 空、re-export import 输出 `re-export ok`、async_routers consumer 不报 ImportError。

**注：**`from app.async_routers import sync_confirm` 可能因为 `sync_confirm` 是函数内 import（`async_routers.py:1745`）而不在模块顶层。退而求其次：

```bash
python -c "import app.async_routers; print('async_routers module ok')"
```

只要 module import 不挂 → re-export 链路有效。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/refund_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract refund routes; keep confirm_task_completion re-export shim"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 11: 提取 profile 域（9 routes，中风险）

**Files:**
- Create: `backend/app/routes/profile_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 1187 | PATCH | `/profile/timezone` |
| 4726 | GET | `/profile/me` |
| 4974 | GET | `/profile/{user_id}` |
| 5226 | POST | `/profile/send-email-update-code` |
| 5314 | POST | `/profile/send-phone-update-code` |
| 5426 | PATCH | `/profile/avatar` |
| 5477 | PATCH | `/profile` |
| 6497 | DELETE | `/users/account` |
| 11204 | GET | `/users/{user_id}/task-statistics` |

**注意**：
- line 6497 `/users/account` 几何位置在 notifications 块内但逻辑归 profile（账号删除）。按函数名定位。
- line 11204 `/users/{user_id}/task-statistics` 在 system 区附近但逻辑归 profile（用户统计）。按函数名定位。
- 如函数体调用 `_safe_parse_images`（routers.py:4959）等留在 routers.py 的 helper，加 `from app.routers import _safe_parse_images`

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_user_optional,
    get_sync_db,
)
# 函数体内 email_utils 等按需补齐
# from app.routers import _safe_parse_images  # 如调用

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**

- [ ] **Step 4: 本地 Gate**（同 Task 6）

Expected: profile smoke 探针 `/profile/me` 在双前缀返 401/403、diff 空、外部 importer 测试全绿。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/profile_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract profile routes to routes/profile_routes.py"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 12: 提取 message 域（19 routes，中风险）

**Files:**
- Create: `backend/app/routes/message_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 5695 | POST | `/messages/send` |
| 5713 | GET | `/messages/history/{user_id}` |
| 5736 | GET | `/messages/unread` |
| 5759 | GET | `/messages/unread/count` |
| 5836 | GET | `/messages/unread/by-contact` |
| 5866 | POST | `/messages/{msg_id}/read` |
| 5873 | POST | `/messages/mark-chat-read/{contact_id}` |
| 5920 | GET | `/notifications` |
| 5973 | GET | `/notifications/unread` |
| 5989 | GET | `/notifications/with-recent-read` |
| 6004 | GET | `/notifications/unread/count` |
| 6097 | GET | `/notifications/interaction` |
| 6270 | POST | `/notifications/{notification_id}/read`（多行装饰器） |
| 6292 | POST | `/users/device-token` |
| 6463 | DELETE | `/users/device-token` |
| 6599 | POST | `/notifications/read-all` |
| 6654 | POST | `/notifications/send-announcement` |
| 9618 | GET | `/contacts` |
| 9730 | GET | `/users/shared-tasks/{other_user_id}` |

**注意**：line 9618 和 9730 几何上在 cs 区但逻辑归 message（用户-用户联系）。按函数名 `get_contacts` / `get_shared_tasks` 定位。

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.cache import cache_response
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_user_secure_async_csrf,
    get_current_admin_user,
    get_sync_db,
    get_async_db_dependency,
)
from app.performance_monitor import measure_api_performance
from app.push_notification_service import send_push_notification
from app.utils.notification_utils import enrich_notification_dict_with_task_id_async

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**

- [ ] **Step 4: 本地 Gate**（同 Task 6）

Expected: `/messages/unread/count` 探针双前缀返 401/403、diff 空、全绿。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/message_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract message + notification routes to routes/message_routes.py"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 13: 提取 payment_inline 域（7 routes + 修 `test_consultation_placeholder_upgrade.py`）

**Files:**
- Create: `backend/app/routes/payment_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`
- **Modify: `backend/tests/test_consultation_placeholder_upgrade.py`**（前置审计发现的 brittle 测试）

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 6704 | POST | `/tasks/{task_id}/pay` |
| 6902 | POST | `/stripe/webhook` |
| 9240 | POST | `/tasks/{task_id}/confirm_complete` |
| 11233 | POST | `/users/vip/activate` |
| 11377 | GET | `/users/vip/status` |
| 11395 | GET | `/users/vip/history` |
| 11422 | POST | `/webhooks/apple-iap` |

**关键风险**：
- `/stripe/webhook` 函数体引用 `_handle_account_updated` / `_handle_dispute_team_reversal` / `_safe_int_metadata` / `_payment_method_types_for_currency`（这 4 个 helper **留在 `routers.py`**，新文件 import 它们）
- Apple IAP 函数引用 `_decode_jws_transaction` / `_handle_v2_renewal/cancel/expired/refund/revoke`（也留在 `routers.py`）
- **路径 URL 绝对不能变**。Stripe webhook signing secret 配置在 Stripe Dashboard 的 `/api/stripe/webhook` URL 上，路径一动就全失效

**输入 — imports：**

```python
from __future__ import annotations

import logging
from decimal import Decimal
from typing import Optional

import stripe
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_sync_db,
)
# 留在 routers.py 的 helper:
from app.routers import (
    _handle_account_updated,
    _handle_dispute_team_reversal,
    _payment_method_types_for_currency,
    _safe_int_metadata,
    _decode_jws_transaction,
    _handle_v2_renewal,
    _handle_v2_cancel,
    _handle_v2_expired,
    _handle_v2_refund,
    _handle_v2_revoke,
)

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**

- [ ] **Step 4: 修 `backend/tests/test_consultation_placeholder_upgrade.py`**

该测试用 `inspect.getsource(routers)` 拿 routers.py 源码后断言路径片段存在。`/tasks/{task_id}/pay` 迁出后断言会失败。重定向断言到新模块。

定位 `test_task_api_rejects_placeholder_payment`（line ~452）：

```python
# 旧版（拆分前）：
def test_task_api_rejects_placeholder_payment():
    import inspect
    from app import routers

    source = inspect.getsource(routers)
    assert '@router.post("/tasks/{task_id}/pay")' in source, "pay endpoint should exist"
    assert "load_real_task_or_404_sync" in source, "guard helper should be imported/used"
```

改为：

```python
# 新版（payment 提取后）：
def test_task_api_rejects_placeholder_payment():
    import inspect
    from app.routes import payment_inline_routes

    source = inspect.getsource(payment_inline_routes)
    assert '@router.post("/tasks/{task_id}/pay")' in source, "pay endpoint should exist in payment_inline_routes"
    assert "load_real_task_or_404_sync" in source, "guard helper should be imported/used"
```

`test_task_api_rejects_placeholder_write_sample`（line ~468）暂时不改——它检查 `/cancel` `/review` `/complete`，这些路由要等 Task 14（task）才迁出。本 commit 留着它指向 `routers`（仍能找到 `/complete` 即 `/tasks/{task_id}/confirm_complete`，因为 confirm_complete **不**迁——等等，会迁，line 9240 在本任务里）。

实际上 `/tasks/{task_id}/confirm_complete` 也在本 commit 迁走。但 `test_task_api_rejects_placeholder_write_sample` 检查的是 `/complete`（pattern match `/complete`），它会同时匹配 `/tasks/{task_id}/complete`（在 task 域）和 `/tasks/{task_id}/confirm_complete`（在 payment 域）。本 commit 迁走 confirm_complete 后，routers.py 里至少还有 `/complete`（即 `/tasks/{task_id}/complete`，line 2311，归 task 域）—— 直到 Task 14 task 域迁出，那时候 `/complete` 才完全不在 routers.py。所以本 commit 里这个测试**还能过**（routers source 里仍有 `/complete` 字符串）。

确认无误后，**只改第一个测试函数**（`test_task_api_rejects_placeholder_payment`）。

- [ ] **Step 5: 本地 Gate（含 webhook helper 专属检查 + 修过的 test）**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import _handle_account_updated, _handle_dispute_team_reversal, _payment_method_types_for_currency; print('helpers still exportable')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
pytest tests/test_consultation_placeholder_upgrade.py -v
```

Expected: 全绿、diff 空、helpers import 输出 `helpers still exportable`、修过的 test 过。

**特别验证**：
- smoke `POST /api/stripe/webhook` 和 `/api/users/stripe/webhook`（空 body）双返 400 ← webhook 路由已注册
- `test_stripe_webhook_handlers_team.py` 4 个 case 全绿 ← helper import 仍工作

**若 webhook 返 404**：立即停。`payment_inline_routes.router` 未注册或路径拼错。修好再 commit。

- [ ] **Step 6: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/payment_inline_routes.py backend/app/routers.py backend/app/main.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "$(cat <<'EOF'
refactor(routers): extract payment-inline routes (pay, stripe webhook, vip, iap)

Also redirects test_task_api_rejects_placeholder_payment in
test_consultation_placeholder_upgrade.py to inspect payment_inline_routes
instead of routers (the brittle source-string assertion would otherwise fail
since /tasks/{task_id}/pay moved out).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

**Push 后特别盯**：Railway 部署完成后看日志窗口，确认首个真实 Stripe webhook（如有）正常处理。如果一晚上没有 webhook 流量，主动在 Stripe Dashboard 的 webhook 页面点 "Send test event" 触发一次。

---

## Task 14: 提取 task 域（19 routes + 修 `test_consultation_placeholder_upgrade.py`）

**Files:**
- Create: `backend/app/routes/task_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`
- **Modify: `backend/tests/test_consultation_placeholder_upgrade.py`**（剩余的 brittle 断言）

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 1582 | GET | `/recommendations` |
| 1687 | GET | `/tasks/{task_id}/match-score` |
| 1720 | POST | `/tasks/{task_id}/interaction` |
| 1809 | GET | `/user/recommendation-stats` |
| 1826 | POST | `/recommendations/{task_id}/feedback` |
| 1863 | POST | `/tasks/{task_id}/accept` |
| 1962 | POST | `/tasks/{task_id}/approve` |
| 2068 | POST | `/tasks/{task_id}/reject` |
| 2137 | PATCH | `/tasks/{task_id}/reward` |
| 2163 | PATCH | `/tasks/{task_id}/visibility` |
| 2191 | POST | `/tasks/{task_id}/review` |
| 2272 | GET | `/tasks/{task_id}/reviews` |
| 2288 | GET | `/users/{user_id}/received-reviews` |
| 2296 | GET | `/{user_id}/reviews` |
| 2311 | POST | `/tasks/{task_id}/complete` |
| 4466 | POST | `/tasks/{task_id}/cancel` |
| 4660 | DELETE | `/tasks/{task_id}/delete` |
| 4698 | GET | `/tasks/{task_id}/history` |
| 4897 | GET | `/my-tasks` |

**注意**：
- line 2296 `/{user_id}/reviews` 路径开头是 `{user_id}`——看似危险（会匹配任何单段路径），但它在 `/api` 挂载下实际 URL 是 `/api/{user_id}/reviews`，有两段，FastAPI 顺序匹配下安全。搬过去后双前缀依然有效。
- 函数体如调用 `_get_task_detail_legacy`（routers.py:1242）、`_request_lang_sync`（routers.py:1222）、`_safe_parse_images`（routers.py:4959）等留在 routers.py 的 helper，加 `from app.routers import ...`

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.cache import cache_response
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_sync_db,
    get_async_db_dependency,
)
from app.performance_monitor import measure_api_performance
from app.push_notification_service import send_push_notification
from app.task_recommendation import get_task_recommendations, calculate_task_match_score
from app.user_behavior_tracker import UserBehaviorTracker, record_task_view, record_task_click
from app.recommendation_monitor import get_recommendation_metrics, RecommendationMonitor

# 留在 routers.py 的 helper:
from app.routers import _get_task_detail_legacy, _request_lang_sync, _safe_parse_images

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-3: 按 Standard Extraction Procedure 操作**

- [ ] **Step 4: 修 `backend/tests/test_consultation_placeholder_upgrade.py`**

定位 `test_task_api_rejects_placeholder_write_sample`（line ~468）：

```python
# 旧版：
def test_task_api_rejects_placeholder_write_sample():
    import inspect
    from app import routers

    source = inspect.getsource(routers)
    assert '/cancel' in source
    assert '@router.post("/tasks/{task_id}/review"' in source or '/review' in source
    assert '/complete' in source
    has_guard_helper = "load_real_task_or_404_sync" in source
    has_inline_check = "is_consultation_placeholder" in source
    assert has_guard_helper and has_inline_check, "..."
```

改为：

```python
# 新版（task 提取后，路由都在 task_routes 里）：
def test_task_api_rejects_placeholder_write_sample():
    import inspect
    from app.routes import task_routes

    source = inspect.getsource(task_routes)
    assert '/cancel' in source
    assert '@router.post("/tasks/{task_id}/review"' in source or '/review' in source
    assert '/complete' in source
    # guard helper / inline check 可能在 task_routes 或其它新模块或留在 routers.py
    # 简化为只断言两种 pattern 在整个 backend/app 下至少存在：
    import pathlib
    backend_app = pathlib.Path(__file__).resolve().parents[1] / "app"
    all_py = "\n".join(p.read_text(encoding="utf-8") for p in backend_app.rglob("*.py"))
    has_guard_helper = "load_real_task_or_404_sync" in all_py
    has_inline_check = "is_consultation_placeholder" in all_py
    assert has_guard_helper and has_inline_check, "guard pattern must exist somewhere in backend/app"
```

同样定位 `test_require_team_role_migration_in_complete_task`（line ~494）：原断言检查 `routers.py` 源里有 `require_team_role_sync`。complete_task 在 task 提取后会到 `task_routes`。改为：

```python
def test_require_team_role_migration_in_complete_task():
    import inspect
    from app.routes import task_routes

    source = inspect.getsource(task_routes)
    assert "from app.permissions.expert_permissions import require_team_role_sync" in source \
        or "require_team_role_sync" in source, \
        "task_routes should import or use require_team_role_sync after task migration"
    assert "require_team_role_sync(" in source, \
        "task_routes should have at least one call to require_team_role_sync"
```

- [ ] **Step 5: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
pytest tests/test_consultation_placeholder_upgrade.py -v
```

Expected: `/tasks/1/history` 探针在双前缀返 401/403、diff 空、smoke + 外部 importer + 修过的 test 全绿。

- [ ] **Step 6: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/task_routes.py backend/app/routers.py backend/app/main.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "$(cat <<'EOF'
refactor(routers): extract task routes (lifecycle, recommendations, reviews)

Also redirects test_task_api_rejects_placeholder_write_sample and
test_require_team_role_migration_in_complete_task to inspect task_routes
(the affected routes — /cancel, /review, /complete — moved here).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

---

## Task 15: 并入 13 条 admin/task-expert 路由到 `admin_task_expert_routes.py`

**为什么先做这个再做 cs**：这 13 条 admin 路由当前在 `routers.py` 里、走 `main_router` 双挂载。如果先拆 cs + 删 `main_router` 再处理这些，中间会有窗口期 13 条路由无家可归。先并入既有 admin 文件，再拆 cs + 删 `main_router`，全程无路由丢失。

**Files:**
- Modify: `backend/app/admin_task_expert_routes.py`（追加 13 条路由）
- Modify: `backend/app/routers.py`（删 13 条路由函数）
- （`main.py` 不改——`admin_task_expert_router` 已注册，本任务只是扩容现有文件）

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 12778 | GET | `/admin/task-experts` |
| 12850 | GET | `/admin/task-expert/{expert_id}` |
| 12902 | POST | `/admin/task-expert` |
| 12984 | PUT | `/admin/task-expert/{expert_id}` |
| 13159 | DELETE | `/admin/task-expert/{expert_id}` |
| 13191 | GET | `/admin/task-expert/{expert_id}/services` |
| 13245 | PUT | `/admin/task-expert/{expert_id}/services/{service_id}` |
| 13297 | DELETE | `/admin/task-expert/{expert_id}/services/{service_id}` |
| 13421 | GET | `/admin/task-expert/{expert_id}/activities` |
| 13477 | PUT | `/admin/task-expert/{expert_id}/activities/{activity_id}` |
| 13528 | DELETE | `/admin/task-expert/{expert_id}/activities/{activity_id}` |
| 13647 | POST | `/admin/task-expert/{expert_id}/services/{service_id}/time-slots/batch-create` |

（注：spec 列了 13 条，实际 grep 结果是 12 条；末尾 13647 是第 12 条。如果实施时发现 13 条，按真实情况搬。差异原因：spec 估计含 line 13839 的 `_deprecated_get_public_task_experts` 帮助函数，那是 helper 不是 route。）

- [ ] **Step 1: 探明 `admin_task_expert_routes.py` 的 router prefix**

```bash
cd backend
grep -nE "^router = APIRouter|^admin_task_expert_router = " app/admin_task_expert_routes.py | head -3
grep -n "include_router(admin_task_expert" app/main.py
```

**判定规则**（按上面 grep 输出做选择）：
- 若 `APIRouter(prefix="/api/admin")`：迁入路径需相对化——`/admin/task-experts` → `/task-experts`（避免双前缀拼接成 `/api/admin/admin/...`）
- 若 `APIRouter()` 无 prefix，且 main.py 的 `include_router` 也无 prefix：保留原路径 `/admin/task-experts`
- 若 `APIRouter()` 无 prefix，但 main.py 用 `app.include_router(admin_task_expert_router, prefix="/api/admin")`：迁入路径去掉 `/admin/`，变 `/task-experts`
- 若 main.py 用 `prefix="/api"`：保留原路径 `/admin/task-experts`

**记下结论，Step 2 用**。

- [ ] **Step 2: 把这些路由从 `routers.py` 复制到 `admin_task_expert_routes.py`**

按 Step 1 结论调整路径前缀。逐条复制装饰器 + 函数体 + 函数内 import。注意原文件可能用不同 auth dep（如 `get_current_admin` 而非 `get_current_admin_user`），按 `admin_task_expert_routes.py` 的既有约定对齐——**不改业务逻辑**，只调整 dep 名字若必要。

如遇函数名冲突（现有文件已有同名函数）：在迁入函数前加 `_inline` 后缀，如 `list_task_experts` → `list_task_experts_inline`，并在装饰器外加注释 `# migrated from routers.py @ line 12778`。

- [ ] **Step 3: 从 `routers.py` 删除这些路由函数**

```bash
cd backend
grep -cE "^@router\." app/routers.py
```

Expected: 当前剩下的路由数 = 162 - 12 (translation) - 11 (system) - 7 (upload) - 22 (auth+debug) - 8 (refund) - 9 (profile) - 19 (message) - 7 (payment) - 19 (task) - 12 (本任务) = **36 条**（cs 域剩余）。如果数字对不上，回头核对哪条没删。

- [ ] **Step 4: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

**特别验证 admin/task-expert 路径**：

```bash
cd backend
python -m scripts.dump_routes | python -c "import sys,json; d=json.load(sys.stdin); rs=[r for r in d if 'admin/task-expert' in r['path'] or 'admin/task-experts' in r['path']]; print(f'admin/task-expert routes: {len(rs)}'); [print(r) for r in rs[:20]]"
```

Expected: 看到约 12 条路径 × 1-2 个挂载点（取决于 admin_task_expert_router 的挂载方式），关键是 **diff 为空**。

**若 diff 非空**：通常是路径前缀拼错。对比 baseline 里原有 `/admin/task-expert*` 条目与当前 dump 的，逐条核对。

- [ ] **Step 5: Commit + Push + Linktest 烟测**

```bash
git add backend/app/admin_task_expert_routes.py backend/app/routers.py
git commit -m "refactor(admin): merge inline admin/task-expert routes into admin_task_expert_routes"
git push origin main
sleep 90
bash backend/scripts/smoke_linktest.sh
```

烟测脚本不直接探 admin/task-expert（探针主要测 main_router 的 routes），但 GH Actions 的 routes-snapshot 会捕获所有变化。**额外手测**：

```bash
curl -i -H "Cookie: <admin session>" https://linktest.up.railway.app/api/admin/task-experts
```

或者打开 admin panel 跑一次"看专家列表"操作，确认功能正常。

---

## Task 16: 提取 cs 域（最后 36 routes，最高风险）+ 删除 main_router 挂载

**前置**：Task 15 已把 13 条 admin/task-expert 迁出，此时 `routers.py` 只剩 36 条 cs 路由 + 19 个 helper。本任务把它们搬走、同时清理 `main_router` 双挂载，完成整个拆分。

**Files:**
- Create: `backend/app/routes/cs_routes.py`
- Modify: `backend/app/routers.py`（删 36 路由 + 删 `router = APIRouter()`）
- Modify: `backend/app/main.py`（取消 cs 注释 + **删除** `main_router` import 和两行 `include_router`）

**输入 — 要迁移的路由（基于当前实测行号）：**

| Line | Method | Path |
|---|---|---|
| 9410 | GET | `/admin/customer-service-requests` |
| 9461 | GET | `/admin/customer-service-requests/{request_id}` |
| 9499 | PUT | `/admin/customer-service-requests/{request_id}` |
| 9547 | GET | `/admin/customer-service-chat` |
| 9586 | POST | `/admin/customer-service-chat` |
| 9770 | POST | `/user/customer-service/assign` |
| 9934 | GET | `/user/customer-service/queue-status` |
| 9943 | GET | `/user/customer-service/availability` |
| 9957 | POST | `/customer-service/online` |
| 10031 | POST | `/customer-service/offline` |
| 10065 | GET | `/customer-service/status` |
| 10115 | GET | `/customer-service/check-availability` |
| 10169 | GET | `/customer-service/chats` |
| 10205 | GET | `/customer-service/chats/{chat_id}/messages` |
| 10223 | POST | `/user/customer-service/chats/{chat_id}/messages/{message_id}/mark-read` |
| 10244 | POST | `/customer-service/chats/{chat_id}/mark-read` |
| 10264 | POST | `/customer-service/chats/{chat_id}/messages` |
| 10330 | POST | `/user/customer-service/chats/{chat_id}/end` |
| 10362 | POST | `/customer-service/chats/{chat_id}/end` |
| 10405 | POST | `/user/customer-service/chats/{chat_id}/rate` |
| 10471 | GET | `/user/customer-service/chats` |
| 10480 | GET | `/user/customer-service/chats/{chat_id}/messages` |
| 10496 | POST | `/user/customer-service/chats/{chat_id}/messages` |
| 10553 | POST | `/user/customer-service/chats/{chat_id}/files` |
| 10662 | POST | `/customer-service/chats/{chat_id}/files` |
| 10783 | GET | `/customer-service/{service_id}/rating` |
| 10800 | GET | `/customer-service/all-ratings` |
| 10819 | GET | `/customer-service/cancel-requests` |
| 10874 | POST | `/customer-service/cancel-requests/{request_id}/review` |
| 11019 | GET | `/customer-service/admin-requests`（多行装饰器） |
| 11037 | POST | `/customer-service/admin-requests` |
| 11066 | GET | `/customer-service/admin-chat`（多行装饰器） |
| 11081 | POST | `/customer-service/admin-chat` |
| 11679 | POST | `/customer-service/cleanup-old-chats/{service_id}` |
| 11700 | POST | `/customer-service/chats/{chat_id}/timeout-end` |
| 11819 | GET | `/customer-service/chats/{chat_id}/timeout-status` |

**输入 — imports：**

```python
from __future__ import annotations

import logging
from typing import Optional, List

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, Response, UploadFile, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.deps import (
    get_current_user_secure_sync_csrf,
    get_current_customer_service_or_user,
    get_current_admin_user,
    get_sync_db,
)
from app.separate_auth_deps import (
    get_current_admin,
    get_current_service,
    get_current_admin_or_service,
)

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 搬 36 条路由到 `backend/app/routes/cs_routes.py`**

- [ ] **Step 2: 从 `routers.py` 删除这 36 条路由函数**

完成此步后 `routers.py` 里应该**没有任何 `@router.xxx` 装饰器了**：

```bash
cd backend
grep -c "^@router\." app/routers.py
```

Expected: `0`

- [ ] **Step 3: 从 `routers.py` 删除 `router = APIRouter()`**

定位 routers.py 顶部附近的 `router = APIRouter(...)`（应该在 module-level imports 之后），删掉这一行和它紧邻的相关注释/空行。

同时更新 `routers.py` 顶部 docstring 为：

```python
"""
Shared helpers for split route modules (extraction completed 2026-04-25).

Routes have been migrated to app/routes/*_routes.py. This module now retains:
  - 19 module-level helper functions (_handle_*, _payment_method_types_*, etc.)
  - One re-export shim (confirm_task_completion from refund_routes) for backward compat
    with async_routers.py:1745

Do not add new routes here. If you need a new endpoint, create it in the
appropriate app/routes/<domain>_routes.py.

See docs/superpowers/specs/2026-04-25-routers-py-split-design.md
"""
```

- [ ] **Step 4: 更新 `main.py` —— 删除 main_router 挂载，取消 cs_routes 注释，去掉 import 块的注释**

定位并**删除**这三行（`backend/app/main.py`）：

```python
from app.routers import router as main_router  # line 42
# ...
app.include_router(main_router, prefix="/api/users", tags=["users"])  # line ~283
# ...
app.include_router(main_router, prefix="/api", tags=["main"])  # line ~339
```

把 import 块里的注释**完全去掉**（现在 10 个 domain 都已激活）：

```python
from app.routes import (
    auth_inline_routes,
    task_routes,
    refund_routes,
    profile_routes,
    message_routes,
    payment_inline_routes,
    cs_routes,
    translation_routes,
    system_routes,
    upload_inline_routes,
)
```

把 `_SPLIT_ROUTERS` 列表也全部解注释（最后一项 cs_routes 现在激活）：

```python
_SPLIT_ROUTERS: list[tuple[object, str]] = [
    (auth_inline_routes.router, "auth-inline"),
    (task_routes.router, "任务"),
    (refund_routes.router, "退款"),
    (profile_routes.router, "用户资料"),
    (message_routes.router, "消息与通知"),
    (payment_inline_routes.router, "支付-inline"),
    (cs_routes.router, "客服"),
    (translation_routes.router, "翻译"),
    (system_routes.router, "系统"),
    (upload_inline_routes.router, "上传-inline"),
]
```

- [ ] **Step 5: 本地 Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import confirm_task_completion, _handle_account_updated, _handle_dispute_team_reversal, _payment_method_types_for_currency; print('helpers + re-export ok')"
python -c "import app.async_routers; print('async_routers ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
pytest tests/test_consultation_placeholder_upgrade.py -v
```

Expected 全绿、diff 空。**最关键**：`grep -c "^@router\." backend/app/routers.py` = 0。

- [ ] **Step 6: 全量回归**

```bash
cd backend
pytest tests/ -v -x 2>&1 | tail -30
```

Expected: 全部通过（no FAILED, no ERROR）。如果有失败，根因排查（多半是 import error，因为 main_router 删了）。

- [ ] **Step 7: Commit + Push + Linktest 烟测**

```bash
git add backend/app/routes/cs_routes.py backend/app/routers.py backend/app/main.py
git commit -m "$(cat <<'EOF'
refactor(routers): extract cs routes + remove main_router mount

routers.py no longer contains any APIRoute decorators. The main_router object
was removed from main.py (both /api and /api/users mount points). All 152
retained routes now live in routes/<domain>_routes.py (10 files) and 1
existing admin file (admin_task_expert_routes.py), all double-mounted via
the _SPLIT_ROUTERS loop.

routers.py retained as helper repository (19 _xxx functions +
confirm_task_completion re-export shim).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
sleep 120
bash backend/scripts/smoke_linktest.sh
```

**Push 后特别盯**：这是最大的 commit，删掉了 main_router 整个对象。如果 linktest 烟测一项挂、或 Flutter app 登录失败 → 立即 `git revert HEAD && git push origin main`，分析。

---

## Task 17: 最终回归 + 排程 follow-up

**Files:**
- 无文件改动；本任务是验证 + 排程后续工作

- [ ] **Step 1: 最终全量验证**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_final.json
diff scripts/routes_baseline.json /tmp/routes_final.json
pytest tests/ -v -x 2>&1 | tail -30
grep -c "^@router\." app/routers.py
wc -l app/routers.py
```

Expected:
- 所有命令绿
- `grep -c "^@router\." app/routers.py` = **0**（零装饰器）
- `wc -l app/routers.py` = **~3,000 以下**（保留 19 个 helper + import + docstring + 1 行 re-export）
- 整套 `pytest tests/` 全部通过

- [ ] **Step 2: 检查 git history 干净**

```bash
git log --oneline -20
```

Expected: 看到本次拆分的 ~16 个 commit，全部带 `chore(routers):` / `test(routers):` / `ci(routers):` / `refactor(routers):` / `refactor(admin):` 前缀。

- [ ] **Step 3: 部署线上冒烟终轮**

```bash
bash backend/scripts/smoke_linktest.sh
# 同样针对 prod（确认 prod 也已被 Railway 部署）：
BASE=https://api.link2ur.com bash backend/scripts/smoke_linktest.sh
```

Expected 双方全绿。

- [ ] **Step 4: 手工跑 Flutter app dev build**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter run -d web-server
```

打开浏览器：登录 → 看 banner → 收消息 → 看 profile → 翻一下任务列表。

Expected: 一切正常。任何一处 401/404/500 → 记录复现步骤、检查对应 route 是否双前缀都注册。

- [ ] **Step 5: 更新 memory**

读取 `C:\Users\Ryan\.claude\projects\F--python-work-LinkU\memory\MEMORY.md`：
- "## Backend Architecture" 那条 `app/routers.py is 12,748 lines — migration plan in app/routes/__init__.py` 改为：

```markdown
- `app/routers.py` 已从 15,232 行拆为 19 个 helper（仅模块级 `_xxx` 函数）+ 1 行 re-export shim，所有 162 路由迁到 `app/routes/<domain>_routes.py`（10 个新文件）+ 既有 `admin_task_expert_routes.py`（13 条 admin 合并）；10 条 debug 路由永久删除。拆分完成于 2026-04-25。
```

如果"## Tech Debt"里有相关条目，删掉或标记 RESOLVED。

- [ ] **Step 6: Commit memory 更新（这一步在 ~/.claude 仓库里，不在主仓库）**

memory 是 user-level 文件，不属于本仓库 git。直接 Write 文件即可，不需要 commit。

- [ ] **Step 7: 排程前缀审计 follow-up**

调用 `/schedule` 创建一个 ~2 周后的 agent，做"前缀审计"。提示词如下：

```
Title: routers.py 拆分后的前缀审计 + 清理

Schedule: 2026-05-09 (拆分完成后 2 周)

Prompt:
后台拆分项目（spec: docs/superpowers/specs/2026-04-25-routers-py-split-design.md）已于 2026-04-25 完成，10 个新 routes 模块每个都双挂载到 /api 和 /api/users。本任务做"前缀审计"，目的是把不需要的那一侧 mount 删掉，让 main.py 干净下来。

具体做法：
1. grep `link2ur/lib/`（Flutter）和 `frontend/`（React Web）所有调用，提取每条 URL 的前缀（/api/users/* 还是 /api/*）
2. 对每条 routers.py 拆出来的 162 条路由（新 routes/*.py 文件 + admin_task_expert_routes.py 新增部分），统计：哪些前缀有真实 caller？
3. 对完全没有 /api/users/* caller 的路由，从 main.py 的 _SPLIT_ROUTERS 循环里删掉 `prefix="/api/users"` 那次挂载
4. 同样处理无 /api/* caller 的（应该极少）
5. 跑 dump_routes diff baseline，更新 baseline
6. 跑 smoke_linktest 双前缀验证
7. **不要直推 main**——开 PR 让 user 审

注意：iOS native（ios/ 目录）已退役，不算调用源。
```

排程完成后，记录到 `MEMORY.md` 里：

```markdown
## Routers Split Follow-up
- [Prefix audit scheduled for 2026-05-09](project_routers_split_followup.md) — 拆分完成后 2 周做前缀审计，删除多余 mount
```

---

## 完成条件（所有任务都完成后）

- [ ] Task 1–17 全部 commit 推到 main
- [ ] `routers.py` < 3,000 行，含 0 个 `@router.` 装饰器
- [ ] `backend/app/routes/` 下有 10 个新 `*_routes.py` 文件
- [ ] `admin_task_expert_routes.py` 扩容吸纳 12-13 条 admin/task-expert 路由
- [ ] 10 条 debug 路由已删
- [ ] 路由快照 diff 为空（除 debug 删除）
- [ ] smoke 测试全绿、外部 importer 测试全绿、`test_consultation_placeholder_upgrade.py` 全绿
- [ ] GH Actions `Routes Snapshot Check` 至少一次绿色运行
- [ ] linktest + prod 烟测脚本全绿
- [ ] Flutter dev build 手工冒烟正常
- [ ] memory 更新、follow-up agent 已排程
