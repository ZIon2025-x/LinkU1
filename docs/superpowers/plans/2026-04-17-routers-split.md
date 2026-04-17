# `backend/app/routers.py` 拆分实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `backend/app/routers.py` 的 162 个路由拆到 10 个 `backend/app/routes/*_routes.py` 文件 + 并入 1 个现有 admin 文件，`routers.py` 保留 17 个模块级辅助函数作为 helper 仓库，客户端行为零回归。

**Architecture:** 每个新文件自带独立 `APIRouter()`，通过 `main.py` 的循环双挂载到 `/api` 和 `/api/users` 两前缀。用 `dump_routes.py` 快照脚本对比路由集合，`test_routers_split_smoke.py` 覆盖每域至少一条路径的双前缀存在性。

**Tech Stack:** FastAPI · SQLAlchemy · Pydantic · pytest · GitHub Actions

**Spec:** `docs/superpowers/specs/2026-04-17-routers-split-design.md`

---

## 标准提取流程（Standard Extraction Procedure）

Tasks 5–14 是 10 个域的提取工作，遵循相同流程。每个任务内会列出该域的**输入**（路由清单 + 必需 imports），然后执行以下步骤：

**Procedure Steps（每次提取必走）：**

1. **打开 `backend/app/routers.py`**，用 Grep 或 Read 工具定位任务卡片中列出的每一条路由（按行号）。
2. **在 `backend/app/routes/<domain>_routes.py` 写新文件**：
   - 顶部 imports：任务卡片指定的具体 imports（仅保留该域用到的）
   - `router = APIRouter()`（**不**加 `prefix=`）
   - 逐条把路由函数（装饰器 + 函数体 + 依赖 helper 的 `from ... import`）从 `routers.py` 复制粘贴过来
3. **从 `routers.py` 删除已迁移的路由函数**（只删路由函数本身，保留其依赖的模块级 `_xxx` helper 不动）。
4. **修改 `backend/app/main.py`**：
   - 在 `from app.routes import (...)` import 块里加上 `<domain>_routes`
   - 在 `_SPLIT_ROUTERS` 列表里加一条 `(<domain>_routes.router, "<中文标签>")`
   - （第一个提取任务需先搭好这个 import 块和列表，见 Task 5）
5. **跑 Gate**（每条都必须绿）：

   ```bash
   cd backend
   python -c "from app.main import app; print('ok')"
   python -m scripts.dump_routes > /tmp/routes_current.json
   diff scripts/routes_baseline.json /tmp/routes_current.json
   pytest tests/test_routers_split_smoke.py -v
   pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
   ```

   **允许的 diff 差异**：
   - 该域的路由在 `/api/*` 和 `/api/users/*` 两处的 `name` 字段可能有所变（因 tags 变化不影响 name）—— name 必须一致，path 和 method 必须一致，集合必须一致
   - Commit 8（auth_inline）后允许 10 条 debug 路由消失

6. **Commit**：消息格式 `refactor(routers): extract <domain> routes`（具体消息在任务卡片里给）

**所有 gate 都绿 → 进下一任务。有 gate 失败 → 修到绿，不 commit 带问题的状态。**

---

## Task 1: 创建工作分支并初始化脚本目录

**Files:**
- Create: `backend/scripts/__init__.py`（空）
- Create: `backend/app/routes/__init__.py`（空 + docstring）

- [ ] **Step 1: 切换到 main 分支，创建 feature 分支**

```bash
git checkout main
git pull origin main
git checkout -b refactor/split-routers
```

Expected: `Switched to a new branch 'refactor/split-routers'`

- [ ] **Step 2: 确认目录 `backend/scripts/` 和 `backend/app/routes/` 存在**

```bash
ls backend/scripts/ 2>&1 || mkdir -p backend/scripts
ls backend/app/routes/ 2>&1 || mkdir -p backend/app/routes
```

- [ ] **Step 3: 创建 `backend/scripts/__init__.py`**

```python
# Empty file - marks scripts/ as a package so `python -m scripts.dump_routes` works
```

- [ ] **Step 4: 创建 `backend/app/routes/__init__.py`**

```python
"""
Route modules extracted from app/routers.py.

Each submodule owns one domain of routes. main.py iterates over them and
double-mounts at /api and /api/users prefixes.

This package intentionally does NOT expose a combined_router — main.py handles
registration directly to match the style of other *_routes.py files in app/.
"""
```

- [ ] **Step 5: Commit**

```bash
git add backend/scripts/__init__.py backend/app/routes/__init__.py
git commit -m "chore(routers): create routes/ and scripts/ package scaffolding"
```

---

## Task 2: 写路由快照脚本 `dump_routes.py`

**Files:**
- Create: `backend/scripts/dump_routes.py`

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

- [ ] **Step 2: 运行脚本生成初始基线**

```bash
cd backend
python -m scripts.dump_routes scripts/routes_baseline.json
```

Expected: stderr 打印 `Wrote N routes to scripts/routes_baseline.json`，N 为当前路由总数（~500+，因为包含所有 *_routes.py）。

- [ ] **Step 3: 验证基线合理**

```bash
head -20 backend/scripts/routes_baseline.json
wc -l backend/scripts/routes_baseline.json
```

Expected: JSON 数组，每个元素有 `method`、`path`、`name`。

- [ ] **Step 4: Commit**

```bash
git add backend/scripts/dump_routes.py backend/scripts/routes_baseline.json
git commit -m "chore(routers): add route snapshot script + baseline for split"
```

---

## Task 3: 写 smoke 测试框架

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


# (prefix, domain, method, path, expected_status_codes)
# Both /api/<p> and /api/users/<p> should be reachable.
SMOKE_PROBES: list[tuple[str, str, tuple[int, ...]]] = [
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

**如果有探针 404**：说明该域路由在当前（未拆分）状态下不在期望路径，立即调查——可能是路径拼写错，或者我对某路由的归属判断有误。修好再进下一步。

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_routers_split_smoke.py
git commit -m "test(routers): add smoke test harness for split refactor"
```

---

## Task 4: 建立 main.py 的循环注册骨架

**Files:**
- Modify: `backend/app/main.py:42` (import) 和 `main.py:272, 328` (mount)

这一步不迁移任何路由，只是把 `main.py` 改成"既双挂载 `main_router`、又预留循环注册拆出来的新 router"的形式。Task 5+ 每次只改 `_SPLIT_ROUTERS` 列表加一行 + import 多一个。

- [ ] **Step 1: 读取 main.py 确认当前注册行**

```bash
grep -n "include_router(main_router" backend/app/main.py
```

Expected 两行：一个 `prefix="/api/users"`，一个 `prefix="/api"`。

- [ ] **Step 2: 修改 main.py**

在 `from app.routers import router as main_router` 下方加一行空的 split routers import：

```python
# After:  from app.routers import router as main_router
# Add:
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

（第一轮用注释形式占位，每个提取任务把自己那一行取消注释。）

在 `app.include_router(main_router, prefix="/api", tags=["main"])` **之后** 加：

```python
# 拆分出的领域 router：每个都双挂载到 /api 和 /api/users，
# 行为等价于 main_router 的双挂载。每次新域提取时往这个列表里加一行。
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

- [ ] **Step 3: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
```

Expected: `ok`、`diff` 输出为空、smoke 全绿。此任务**不应**改变任何路由。

- [ ] **Step 4: Commit**

```bash
git add backend/app/main.py
git commit -m "refactor(routers): add main.py scaffolding for split-router registration"
```

---

## Task 5: 提取 translation 域（12 routes，最简单、最低风险）

**Files:**
- Create: `backend/app/routes/translation_routes.py`
- Modify: `backend/app/routers.py`（删除 12 个路由函数）
- Modify: `backend/app/main.py`（取消 `translation_routes` 的注释）

**输入 — 要迁移的路由**（在 `routers.py` 中的行号）：

| Line | Method | Path |
|---|---|---|
| 13880 | POST | `/translate` |
| 14171 | POST | `/translate/batch` |
| 14346 | GET | `/translate/task/{task_id}` |
| 14386 | POST | `/translate/task/{task_id}` |
| 14581 | POST | `/translate/tasks/batch` |
| 14700 | GET | `/translate/metrics` |
| 14727 | GET | `/translate/services/status` |
| 14775 | POST | `/translate/services/reset` |
| 14820 | GET | `/translate/services/failed` |
| 14844 | GET | `/translate/alerts` |
| 14878 | POST | `/translate/prefetch` |
| 14934 | POST | `/translate/warmup` |

**输入 — 新文件 imports**（仅翻译用到的；具体以实际函数体需要为准）：

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
from app.utils.translation_metrics import TranslationTimer
# 其它依赖按实际函数体出现的 import 补齐

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 按 Standard Extraction Procedure Step 2 创建 `backend/app/routes/translation_routes.py`**

把上表 12 条路由的装饰器 + 函数体从 `routers.py` 原样复制到新文件。注意：
- 装饰器保持 `@router.post(...)` / `@router.get(...)` 原样
- 函数内部如 `from app.xxx import ...` 这种**函数内 import** 连同搬过去
- 如果路由函数调用了 `routers.py` 里的模块级 `_xxx` helper（如 `_translate_missing_tasks_async` at line 115，`_trigger_background_translation_prefetch` at line 162），在新文件顶部加：`from app.routers import _translate_missing_tasks_async, _trigger_background_translation_prefetch`

- [ ] **Step 2: 按 Procedure Step 3 从 `routers.py` 删除这 12 个路由函数**

逐条定位、删除装饰器 + 函数体 + 紧邻该函数的函数内 import 和注释（只删该函数范围内的）。保留 `routers.py` 顶部的模块级 `_translate_missing_tasks_async` 和 `_trigger_background_translation_prefetch`。

- [ ] **Step 3: 按 Procedure Step 4 更新 `main.py`**

- 在 import 块里取消 `translation_routes` 那一行的注释
- 在 `_SPLIT_ROUTERS` 里取消 `(translation_routes.router, "翻译")` 那一行的注释

- [ ] **Step 4: 跑 Gate**（Procedure Step 5 的命令）

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected:
- `ok`
- `diff` 为空（只是 tags 变了，name/path/method 全部一致——name 稳定因为函数名没变）
- smoke 全绿（translation 的 `/translate/metrics` 探针在双前缀都能打到）
- 外部 importer 测试绿

**若 `diff` 非空**：说明有路由的 name 变了或丢了。停下来检查——可能某个函数忘记搬，或函数名拼写变了。

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/translation_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract translation routes to routes/translation_routes.py"
```

---

## Task 6: 提取 system 域（11 routes，低风险）

**Files:**
- Create: `backend/app/routes/system_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 11035 | GET | `/stats` |
| 11061 | GET | `/system-settings/public` |
| 11530 | GET | `/user-preferences` |
| 11559 | PUT | `/user-preferences` |
| 11715 | GET | `/timezone/info` |
| 12544 | GET | `/job-positions` |
| 12615 | POST | `/job-applications` |
| 15001 | GET | `/banners` |
| 15045 | GET | `/app/version-check` |
| 15079 | GET | `/faq` |
| 15127 | GET | `/legal/{doc_type}` |

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

logger = logging.getLogger(__name__)

router = APIRouter()
```

如路由调用 `_parse_semver`（line ~15036 in routers.py），加 `from app.routers import _parse_semver`。

- [ ] **Step 1: 按 Standard Extraction Procedure 操作**（参考 Task 5 具体步骤 1-4）

- [ ] **Step 2: 在 main.py 取消 `system_routes` 注释 + `(system_routes.router, "系统")` 列表项注释**

- [ ] **Step 3: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: 全绿、diff 空。system 有两个探针（`/banners`、`/faq`），都应过。

- [ ] **Step 4: Commit**

```bash
git add backend/app/routes/system_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract system routes to routes/system_routes.py"
```

---

## Task 7: 提取 upload_inline 域（7 routes，中风险）

**Files:**
- Create: `backend/app/routes/upload_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 11862 | POST | `/upload/image` |
| 11956 | POST | `/upload/public-image` (deprecated=True) |
| 12116 | POST | `/refresh-image-url` |
| 12161 | GET | `/private-image/{image_id}` |
| 12181 | POST | `/messages/generate-image-url` |
| 12360 | POST | `/upload/file` |
| 12418 | GET | `/private-file` |

**风险点**：文件名 `upload_inline_routes.py` 与已存在的 `upload_routes.py`、`upload_v2_router` 不要混淆。确认 main.py 的 `app.include_router(upload_v2_router, ...)` 不被本任务影响。

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
from app.file_utils import *  # 或按函数实际使用补齐

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 按 Standard Extraction Procedure 执行**

- [ ] **Step 2: 更新 main.py（取消对应两行注释）**

- [ ] **Step 3: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: diff 空、全绿。smoke 的 `POST /upload/image`（无 file）应返回 401/403/422。

- [ ] **Step 4: Commit**

```bash
git add backend/app/routes/upload_inline_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract upload-inline routes to routes/upload_inline_routes.py"
```

---

## Task 8: 提取 auth_inline 域 + 删除 10 条 debug + 迁移 /logout

**Files:**
- Create: `backend/app/routes/auth_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由（12 条保留）：**

| Line | Method | Path |
|---|---|---|
| 209 | POST | `/csp-report` |
| 236 | POST | `/password/validate` |
| 275 | POST | `/register` |
| 533 | GET | `/verify-email` |
| 534 | GET | `/verify-email/{token}` |
| 728 | POST | `/resend-verification` |
| 762 | POST | `/admin/login` |
| 801 | GET | `/user/info` |
| 991 | GET | `/confirm/{token}` |
| 1004 | POST | `/forgot_password` |
| 1073 | POST | `/reset_password/{token}` |
| **9982** | POST | `/logout` ← **此条在 cs 区但逻辑归 auth，单独挑出** |

**输入 — 要删除的路由（10 条 debug，不迁移）：**

| Line | Method | Path |
|---|---|---|
| 227 | POST | `/register/test` |
| 265 | POST | `/register/debug` |
| 817 | GET | `/debug/test-token/{token}` |
| 845 | GET | `/debug/simple-test` |
| 850 | POST | `/debug/fix-avatar-null` |
| 871 | GET | `/debug/check-user-avatar/{user_id}` |
| 892 | GET | `/debug/test-reviews/{user_id}` |
| 897 | GET | `/debug/session-status` |
| 935 | GET | `/debug/check-pending/{email}` |
| 983 | GET | `/debug/test-confirm-simple` |

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

- [ ] **Step 1: 按 Standard Extraction Procedure 把 12 条保留路由搬到新文件**（**不要**搬 10 条 debug）

- [ ] **Step 2: 从 `routers.py` 删除全部 22 条（12 条已迁走 + 10 条 debug 直接删）**

- [ ] **Step 3: 更新 main.py（取消 auth_inline_routes 两行注释）**

- [ ] **Step 4: 更新 smoke test 的 baseline 预期**

因为删除了 10 条 debug 路由，`dump_routes` 结果会比 baseline 少 10 × 2前缀 = 20 条。**更新 baseline**：

```bash
cd backend
python -m scripts.dump_routes scripts/routes_baseline.json
```

然后在 commit 里把新 baseline 一起 commit，commit message 里备注「删 10 条 debug + 更新 baseline」。

- [ ] **Step 5: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected: diff 空（baseline 已更新）、smoke 全绿（auth_inline 的 `/csp-report` 探针过）。

**手动验证 debug 删除**：

```bash
cd backend
python -m scripts.dump_routes | grep -E "/(debug|register/test|register/debug)" || echo "✓ debug routes removed"
```

Expected: `✓ debug routes removed`。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/auth_inline_routes.py backend/app/routers.py backend/app/main.py backend/scripts/routes_baseline.json
git commit -m "$(cat <<'EOF'
refactor(routers): extract auth-inline routes + delete 10 debug endpoints

Deleted:
- POST /register/test, /register/debug
- GET/POST /debug/{test-token,simple-test,fix-avatar-null,check-user-avatar,test-reviews,session-status,check-pending,test-confirm-simple}

Migrated 12 auth routes (including /logout reassigned from cs region) to
routes/auth_inline_routes.py. Baseline refreshed to reflect deletions.
EOF
)"
```

---

## Task 9: 提取 refund 域（8 routes，中风险，包含 `confirm_task_completion` 重导出）

**Files:**
- Create: `backend/app/routes/refund_routes.py`
- Modify: `backend/app/routers.py`（加一行 re-export）
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path | 函数名 |
|---|---|---|---|
| 2545 | POST | `/tasks/{task_id}/dispute` | `dispute_task` (or similar) |
| 2673 | POST | `/tasks/{task_id}/refund-request` | `request_refund` |
| 3008 | GET | `/tasks/{task_id}/refund-status` | `get_refund_status` |
| 3094 | GET | `/tasks/{task_id}/dispute-timeline` | `get_dispute_timeline` |
| 3428 | GET | `/tasks/{task_id}/refund-history` | `get_refund_history` |
| 3524 | POST | `/tasks/{task_id}/refund-request/{refund_id}/cancel` | `cancel_refund` |
| 3653 | POST | `/tasks/{task_id}/refund-request/{refund_id}/rebuttal` | `rebut_refund` |
| 3934 | POST | `/tasks/{task_id}/confirm_completion` | **`confirm_task_completion`** ← 被 `async_routers.py:1743` import |

**关键**：line 3934 的 `confirm_task_completion` 被 `async_routers.py:1743` 通过 `from app.routers import confirm_task_completion as sync_confirm` import。搬走后必须在 `routers.py` 留一个 re-export。

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

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1: 按 Standard Extraction Procedure 搬 8 条路由**

- [ ] **Step 2: 在 `routers.py` 末尾加 re-export shim**

```python
# === Re-exports for backward compat with external importers ===
# async_routers.py:1743 imports this; kept re-exportable until downstream updates.
from app.routes.refund_routes import confirm_task_completion  # noqa: F401
```

- [ ] **Step 3: 更新 main.py（取消 refund_routes 两行注释）**

- [ ] **Step 4: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import confirm_task_completion; print('re-export ok')"
python -c "from app.async_routers import *; print('async_routers ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected 全绿、diff 空、两个额外 import 检查通过。

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/refund_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract refund routes; keep confirm_task_completion re-export"
```

---

## Task 10: 提取 profile 域（9 routes，中风险）

**Files:**
- Create: `backend/app/routes/profile_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 1186 | PATCH | `/profile/timezone` |
| 4726 | GET | `/profile/me` |
| 4983 | GET | `/profile/{user_id}` |
| 5236 | POST | `/profile/send-email-update-code` |
| 5324 | POST | `/profile/send-phone-update-code` |
| 5436 | PATCH | `/profile/avatar` |
| 5487 | PATCH | `/profile` |
| 6507 | DELETE | `/users/account` |
| 11131 | GET | `/users/{user_id}/task-statistics` |

**注意**：line 6507 `/users/account` 在 notifications 代码块内但逻辑归 profile（账号删除）。需按函数定位而非按连续行块搬。

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
from app.email_utils import send_email_with_attachment

# 如函数体内引用 _safe_parse_images（line 4968），加：
# from app.routers import _safe_parse_images

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-4: 按 Standard Extraction Procedure 执行**

- [ ] **Step 5: Gate**（同 Task 6 命令）

Expected: profile smoke 探针 `/profile/me` 在双前缀都返回 401/403。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/profile_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract profile routes to routes/profile_routes.py"
```

---

## Task 11: 提取 message 域（19 routes，中风险）

**Files:**
- Create: `backend/app/routes/message_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 5705 | POST | `/messages/send` |
| 5723 | GET | `/messages/history/{user_id}` |
| 5746 | GET | `/messages/unread` |
| 5769 | GET | `/messages/unread/count` |
| 5846 | GET | `/messages/unread/by-contact` |
| 5876 | POST | `/messages/{msg_id}/read` |
| 5883 | POST | `/messages/mark-chat-read/{contact_id}` |
| 5930 | GET | `/notifications` |
| 5983 | GET | `/notifications/unread` |
| 5999 | GET | `/notifications/with-recent-read` |
| 6014 | GET | `/notifications/unread/count` |
| 6107 | GET | `/notifications/interaction` |
| 6280 | POST | `/notifications/{notification_id}/read` |
| 6302 | POST | `/users/device-token` |
| 6473 | DELETE | `/users/device-token` |
| 6609 | POST | `/notifications/read-all` |
| 6664 | POST | `/notifications/send-announcement` |
| 9545 | GET | `/contacts` |
| 9657 | GET | `/users/shared-tasks/{other_user_id}` |

**注意**：line 9545 和 9657 几何上在 cs 区但逻辑归 message（用户-用户联系）。按函数名 `get_contacts` / `get_shared_tasks` 搬。

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

- [ ] **Step 1-4: 按 Standard Extraction Procedure 执行**

- [ ] **Step 5: Gate**（同 Task 6 命令）

Expected: `/messages/unread/count` 探针双前缀返 401/403。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/message_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract message + notification routes to routes/message_routes.py"
```

---

## Task 12: 提取 payment_inline 域（7 routes，高风险 — Stripe webhook）

**Files:**
- Create: `backend/app/routes/payment_inline_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 6714 | POST | `/tasks/{task_id}/pay` |
| 6912 | POST | `/stripe/webhook` |
| 9167 | POST | `/tasks/{task_id}/confirm_complete` |
| 11160 | POST | `/users/vip/activate` |
| 11304 | GET | `/users/vip/status` |
| 11322 | GET | `/users/vip/history` |
| 11349 | POST | `/webhooks/apple-iap` |

**关键风险**：
- `/stripe/webhook` 的处理函数体引用 `_handle_account_updated`、`_handle_dispute_team_reversal`、`_safe_int_metadata`、`_payment_method_types_for_currency`（这 4 个 helper **留在 `routers.py`**，本文件 import 它们）
- Apple IAP 函数引用 `_decode_jws_transaction`、`_handle_v2_renewal/cancel/expired/refund/revoke`（也留在 `routers.py`）
- **路径 URL 绝对不能变**。Stripe webhook 的 signing secret 是配置在 Stripe Dashboard 的 `/api/stripe/webhook` URL 上，路径一动就全失效

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
# 从 routers.py 引用留下的 helper:
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

- [ ] **Step 1-4: 按 Standard Extraction Procedure 执行**

- [ ] **Step 5: Gate（含 webhook helper 专属检查）**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import _handle_account_updated, _handle_dispute_team_reversal, _payment_method_types_for_currency; print('helpers still exportable')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected 全绿。**特别验证**：
- smoke `POST /api/stripe/webhook` 和 `/api/users/stripe/webhook`（空 body）双返 400 ← webhook 路由已注册
- `test_stripe_webhook_handlers_team.py` 4 个 case 全绿 ← helper import 仍工作

**若 webhook 返 404**：立即停，`payment_inline_routes.router` 未注册或路径拼错。修好再 commit。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/payment_inline_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract payment-inline routes (pay, stripe webhook, vip, iap)"
```

---

## Task 13: 提取 task 域（19 routes，高风险 — 核心业务）

**Files:**
- Create: `backend/app/routes/task_routes.py`
- Modify: `backend/app/routers.py`
- Modify: `backend/app/main.py`

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 1581 | GET | `/recommendations` |
| 1686 | GET | `/tasks/{task_id}/match-score` |
| 1719 | POST | `/tasks/{task_id}/interaction` |
| 1808 | GET | `/user/recommendation-stats` |
| 1825 | POST | `/recommendations/{task_id}/feedback` |
| 1862 | POST | `/tasks/{task_id}/accept` |
| 1964 | POST | `/tasks/{task_id}/approve` |
| 2070 | POST | `/tasks/{task_id}/reject` |
| 2141 | PATCH | `/tasks/{task_id}/reward` |
| 2167 | PATCH | `/tasks/{task_id}/visibility` |
| 2195 | POST | `/tasks/{task_id}/review` |
| 2276 | GET | `/tasks/{task_id}/reviews` |
| 2292 | GET | `/users/{user_id}/received-reviews` |
| 2300 | GET | `/{user_id}/reviews` |
| 2315 | POST | `/tasks/{task_id}/complete` |
| 4481 | POST | `/tasks/{task_id}/cancel` |
| 4660 | DELETE | `/tasks/{task_id}/delete` |
| 4698 | GET | `/tasks/{task_id}/history` |
| 4906 | GET | `/my-tasks` |

**注意**：
- line 2300 `/{user_id}/reviews` 路径开头是 `{user_id}`——看似危险（会匹配任何单段路径），但它在 `/api` 挂载下实际 URL 是 `/api/{user_id}/reviews`，有两段，顺序关系需保持。搬过去后双前缀依然有效
- `_get_task_detail_legacy`（line 1241 in routers.py）若被这些路由调用，加 `from app.routers import _get_task_detail_legacy`
- `_request_lang_sync`（line 1221）同理

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

# 如路由体调用留在 routers.py 的 helper:
from app.routers import _get_task_detail_legacy, _request_lang_sync, _safe_parse_images

logger = logging.getLogger(__name__)

router = APIRouter()
```

- [ ] **Step 1-4: 按 Standard Extraction Procedure 执行**

- [ ] **Step 5: Gate**（同 Task 6 命令）

Expected: `/tasks/1/history` 探针在双前缀返 401/403。diff 空、smoke + 外部 importer 测试全绿。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/task_routes.py backend/app/routers.py backend/app/main.py
git commit -m "refactor(routers): extract task routes (lifecycle, recommendations, reviews)"
```

---

## Task 14: 并入 12 条 admin/task-expert 路由到现有 `admin_task_expert_routes.py`

**为什么先做这个**：这 12 条路由当前在 `routers.py` 里、走 `main_router` 双挂载。如果先拆 cs + 删 `main_router` 再处理这些，中间会有一段时间这 12 条路由无家可归。先把它们并入既有文件，再拆 cs + 删 `main_router`，全程无路由丢失。

**Files:**
- Modify: `backend/app/admin_task_expert_routes.py`（追加 12 条路由）
- Modify: `backend/app/routers.py`（删除这 12 条路由函数）
- （`main.py` 不改——`admin_task_expert_router` 已注册，扩容现有文件即可）

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 12705 | GET | `/admin/task-experts` |
| 12777 | GET | `/admin/task-expert/{expert_id}` |
| 12829 | POST | `/admin/task-expert` |
| 12911 | PUT | `/admin/task-expert/{expert_id}` |
| 13086 | DELETE | `/admin/task-expert/{expert_id}` |
| 13118 | GET | `/admin/task-expert/{expert_id}/services` |
| 13172 | PUT | `/admin/task-expert/{expert_id}/services/{service_id}` |
| 13224 | DELETE | `/admin/task-expert/{expert_id}/services/{service_id}` |
| 13348 | GET | `/admin/task-expert/{expert_id}/activities` |
| 13404 | PUT | `/admin/task-expert/{expert_id}/activities/{activity_id}` |
| 13455 | DELETE | `/admin/task-expert/{expert_id}/activities/{activity_id}` |
| 13574 | POST | `/admin/task-expert/{expert_id}/services/{service_id}/time-slots/batch-create` |

- [ ] **Step 1: 探明现有 `admin_task_expert_routes.py` 的 router prefix**

```bash
cd backend
grep -n "^router = APIRouter\|^admin_task_expert_router = " app/admin_task_expert_routes.py
grep -n "include_router(admin_task_expert" app/main.py
```

**判定规则**：
- 若现有 `APIRouter(prefix="/api/admin")`：迁入路径需相对化——`/admin/task-experts` → `/task-experts`（避免双前缀）
- 若现有 `APIRouter()` 无 prefix，且 `main.py` 的 `include_router` 也不加 prefix：保留原路径 `/admin/task-experts`
- 若现有 `APIRouter()` 无 prefix，但 `main.py` 用 `app.include_router(admin_task_expert_router, prefix="/api/admin")`：迁入路径去掉 `/admin`，变 `/task-experts`

记下结论供 Step 2 使用。

- [ ] **Step 2: 把 12 条路由函数从 `routers.py` 复制到 `admin_task_expert_routes.py`**

按 Step 1 的结论调整路径前缀。逐条复制装饰器 + 函数体 + 函数内 import。注意原文件可能使用不同的 auth dep（如 `get_current_admin` 而非 `get_current_admin_user`），按 `admin_task_expert_routes.py` 的既有约定对齐——**不改业务逻辑**，只调整 dep 名字若必要。

如遇到函数名冲突（现有文件里已有同名函数）：在迁入函数前加 `_inline` 后缀，如 `list_task_experts` → `list_task_experts_inline`，并在装饰器外加注释 `# migrated from routers.py @ line 12705`。

- [ ] **Step 3: 从 `routers.py` 删除这 12 条路由函数**

```bash
cd backend
grep -cE "^@router\." app/routers.py
```

Expected: `36`（只剩 cs 域的 36 条路由，等 Task 15 处理）。

- [ ] **Step 4: Gate**

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
python -m scripts.dump_routes | grep -E "admin/task-expert" | sort
```

Expected: 12 条路径，每条可能在 1 或 2 个前缀下可见（取决于 `admin_task_expert_router` 的挂载方式和 `main_router` 的双挂载合并）——**关键是 diff 为空**。

**若 diff 非空**：通常是路径前缀拼错导致路径变化。对比 baseline 里原有 `/admin/task-expert*` 条目与当前 dump 的 `/admin/task-expert*` 条目，逐条核对。

- [ ] **Step 5: Commit**

```bash
git add backend/app/admin_task_expert_routes.py backend/app/routers.py
git commit -m "refactor(admin): merge inline admin/task-expert routes into admin_task_expert_routes"
```

---

## Task 15: 提取 cs 域（36 routes，最高风险，同时清理 main_router 挂载）

**前置**：Task 14 已把 admin/task-expert 12 条路由迁出。此时 `routers.py` 只剩 36 条 cs 路由。本任务把它们搬走、同时清理 `main_router` 的双挂载，完成整个拆分。

**Files:**
- Create: `backend/app/routes/cs_routes.py`
- Modify: `backend/app/routers.py`（删路由 + 删 `router = APIRouter()`）
- Modify: `backend/app/main.py`（取消 cs 注释 + **删除** `main_router` 的 import 和两行 `include_router`）

**输入 — 要迁移的路由：**

| Line | Method | Path |
|---|---|---|
| 9337 | GET | `/admin/customer-service-requests` |
| 9388 | GET | `/admin/customer-service-requests/{request_id}` |
| 9426 | PUT | `/admin/customer-service-requests/{request_id}` |
| 9474 | GET | `/admin/customer-service-chat` |
| 9513 | POST | `/admin/customer-service-chat` |
| 9697 | POST | `/user/customer-service/assign` |
| 9861 | GET | `/user/customer-service/queue-status` |
| 9870 | GET | `/user/customer-service/availability` |
| 9884 | POST | `/customer-service/online` |
| 9958 | POST | `/customer-service/offline` |
| 9992 | GET | `/customer-service/status` |
| 10042 | GET | `/customer-service/check-availability` |
| 10096 | GET | `/customer-service/chats` |
| 10132 | GET | `/customer-service/chats/{chat_id}/messages` |
| 10150 | POST | `/user/customer-service/chats/{chat_id}/messages/{message_id}/mark-read` |
| 10171 | POST | `/customer-service/chats/{chat_id}/mark-read` |
| 10191 | POST | `/customer-service/chats/{chat_id}/messages` |
| 10257 | POST | `/user/customer-service/chats/{chat_id}/end` |
| 10289 | POST | `/customer-service/chats/{chat_id}/end` |
| 10332 | POST | `/user/customer-service/chats/{chat_id}/rate` |
| 10398 | GET | `/user/customer-service/chats` |
| 10407 | GET | `/user/customer-service/chats/{chat_id}/messages` |
| 10423 | POST | `/user/customer-service/chats/{chat_id}/messages` |
| 10480 | POST | `/user/customer-service/chats/{chat_id}/files` |
| 10589 | POST | `/customer-service/chats/{chat_id}/files` |
| 10710 | GET | `/customer-service/{service_id}/rating` |
| 10727 | GET | `/customer-service/all-ratings` |
| 10746 | GET | `/customer-service/cancel-requests` |
| 10801 | POST | `/customer-service/cancel-requests/{request_id}/review` |
| 10946 | GET | `/customer-service/admin-requests` |
| 10964 | POST | `/customer-service/admin-requests` |
| 10993 | GET | `/customer-service/admin-chat` |
| 11008 | POST | `/customer-service/admin-chat` |
| 11606 | POST | `/customer-service/cleanup-old-chats/{service_id}` |
| 11627 | POST | `/customer-service/chats/{chat_id}/timeout-end` |
| 11746 | GET | `/customer-service/chats/{chat_id}/timeout-status` |

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

完成此步后 `routers.py` 里应该**没有任何 `@router.xxx` 装饰器了**。验证：

```bash
cd backend
grep -c "^@router\." app/routers.py
```

Expected: `0`

- [ ] **Step 3: 从 `routers.py` 删除 `router = APIRouter()`**

定位 line ~90 的 `router = APIRouter()`，删掉这一行和它紧邻的注释/空行。

同时更新 `routers.py` 顶部 docstring 为：

```python
"""
Shared helpers for route modules (extracted 2026-04-17).

Routes have been migrated to app/routes/*_routes.py. This module now retains:
  - ~17 module-level helper functions (_handle_*, _payment_method_types_*, etc.)
  - One re-export shim (confirm_task_completion) for backward compat

Do not add new routes here. If you need a new endpoint, create it in the
appropriate app/routes/<domain>_routes.py.
"""
```

- [ ] **Step 4: 更新 `main.py` —— 删除 main_router 挂载，取消 cs_routes 注释**

在 `main.py` 里找到并**删除**：

```python
from app.routers import router as main_router
...
app.include_router(main_router, prefix="/api/users", tags=["users"])  # delete
...
app.include_router(main_router, prefix="/api", tags=["main"])  # delete
```

在 `_SPLIT_ROUTERS` 里取消 `(cs_routes.router, "客服")` 注释。

同时把 `from app.routes import (...)` import 块里的注释完全去掉（现在 10 个 domain 都已激活）：

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

- [ ] **Step 5: Gate**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -c "from app.routers import confirm_task_completion, _handle_account_updated, _handle_dispute_team_reversal, _payment_method_types_for_currency; print('helpers + re-export ok')"
python -c "from app.async_routers import *; print('async_routers ok')"
python -m scripts.dump_routes > /tmp/routes_current.json
diff scripts/routes_baseline.json /tmp/routes_current.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
```

Expected 全绿、diff 空。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/cs_routes.py backend/app/routers.py backend/app/main.py
git commit -m "$(cat <<'EOF'
refactor(routers): extract cs routes + remove main_router mount

routers.py no longer contains any APIRoute decorators. The main_router object
was removed from main.py (both /api and /api/users mount points). All 152
retained routes now live in routes/<domain>_routes.py (10 files) and are
double-mounted via the _SPLIT_ROUTERS loop.

routers.py retained as helper repository (17 _xxx functions +
confirm_task_completion re-export).
EOF
)"
```

---

## Task 16: 加 CI workflow

**Files:**
- Create: `.github/workflows/routes-snapshot.yml`

- [ ] **Step 1: 创建 workflow 文件**

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
          pip install -r tests/requirements-test.txt

      - name: Compare route snapshot
        working-directory: backend
        env:
          DATABASE_URL: postgresql+psycopg2://postgres:password@localhost:5432/linku_db
        run: |
          python -m scripts.dump_routes > /tmp/routes_current.json
          if ! diff -u scripts/routes_baseline.json /tmp/routes_current.json; then
            echo "::error::Route snapshot has diverged from baseline."
            echo "If intentional, regenerate: python -m scripts.dump_routes scripts/routes_baseline.json"
            exit 1
          fi

      - name: Run smoke test
        working-directory: backend
        env:
          DATABASE_URL: postgresql+psycopg2://postgres:password@localhost:5432/linku_db
        run: pytest tests/test_routers_split_smoke.py -v
```

- [ ] **Step 2: 本地验证 workflow YAML 语法**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/routes-snapshot.yml'))"
```

Expected: 无输出（解析成功）。

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/routes-snapshot.yml
git commit -m "ci: add routes snapshot check + smoke test workflow"
```

---

## Task 17: 最终合并回 main

- [ ] **Step 1: 最终全量验证**

```bash
cd backend
python -c "from app.main import app; print('ok')"
python -m scripts.dump_routes > /tmp/routes_final.json
diff scripts/routes_baseline.json /tmp/routes_final.json
pytest tests/test_routers_split_smoke.py -v
pytest tests/test_stripe_webhook_handlers_team.py tests/test_team_dispute_reversal.py -v
pytest tests/ -v -x 2>&1 | tail -30
grep -c "^@router\." app/routers.py
wc -l app/routers.py
```

Expected:
- 所有上述命令绿
- `grep -c "^@router\." app/routers.py` = **0**（零装饰器）
- `wc -l app/routers.py` = **~3,000 以下**
- 整套 `pytest tests/` 全部通过

- [ ] **Step 2: 查看 commit 历史**

```bash
git log --oneline main..refactor/split-routers
```

Expected: 按顺序 16 个 commit（Tasks 1–16），全部带 `refactor(routers):`、`refactor(admin):`、`chore(routers):`、`test(routers):` 或 `ci:` 前缀。

- [ ] **Step 3: 切换到 main，fast-forward merge**

```bash
git checkout main
git merge --ff-only refactor/split-routers
```

**若非 ff**：说明 main 分支在分支创建后有新提交。先 `git pull --rebase origin main`，再 rebase feature 分支：`git checkout refactor/split-routers; git rebase main`。解决冲突后再 ff-merge。

- [ ] **Step 4: Push 到远程**

```bash
git push origin main
```

**本地可选** — 若想先开 PR self-review：

```bash
# 跳过 Step 3-4，改为：
git push origin refactor/split-routers
gh pr create --title "refactor(routers): split routers.py (15,159 lines → 10 domain files)" --body "$(cat <<'EOF'
## Summary
Split backend/app/routers.py (15,159 lines) into 10 domain files under backend/app/routes/, merged 12 admin routes into existing file, deleted 10 debug routes.

See docs/superpowers/specs/2026-04-17-routers-split-design.md for full design.

## Test plan
- [x] Route snapshot diff empty
- [x] Smoke test 22 assertions green
- [x] Stripe webhook handler tests green
- [x] Team dispute reversal tests green
- [x] Full pytest suite green
- [ ] Smoke on staging post-merge (curl key endpoints at both /api and /api/users)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: 本地清理**

```bash
git branch -d refactor/split-routers
```

- [ ] **Step 6: 线上冒烟**

合并到 Railway 部署的 main 后，等部署完成，curl 验证核心端点：

```bash
curl -i https://linktest.up.railway.app/api/banners
curl -i https://linktest.up.railway.app/api/users/banners
curl -i -X POST https://linktest.up.railway.app/api/stripe/webhook -d '{}' -H "Content-Type: application/json"
```

Expected: `/banners` 双前缀都 200，`/stripe/webhook` 返 400（签名缺失）而非 404。

- [ ] **Step 7: 更新 memory**

在 `C:\Users\Ryan\.claude\projects\F--python-work-LinkU\memory\MEMORY.md` 里把 "## Tech Debt" 下的 `routers.py 12,748 行` 那条移除，改为一条 "Backend Architecture" 条目：`routers.py` 已拆为 10 个 `routes/*_routes.py` 文件 + 保留 helper 仓库。

---

## 完成条件（所有任务都完成后）

- [x] Task 1–17 全部 commit 并合并到 main
- [x] `routers.py` < 3,000 行，含 0 个 `@router.` 装饰器
- [x] `backend/app/routes/` 下有 10 个新文件
- [x] `admin_task_expert_routes.py` 扩容吸纳 12 条 admin/task-expert 路由
- [x] 10 条 debug 路由已删
- [x] 路由快照 diff 为空（除 debug 删除）
- [x] smoke 测试全绿、外部 importer 测试全绿、CI workflow 生效
- [x] memory 更新、线上冒烟过
