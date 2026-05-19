# 学生认证 open-by-suffix 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把学生认证从 121 条手动白名单切换到 "`.ac.uk` 后缀 + 注册域懒加载" 模式,加完 BCU 等漏录学校,且未来新学校 / rebrand 自动兜底。

**Architecture:** `app/university_matcher.py` 重写为"提取注册域 → SELECT universities;不命中则 INSERT(name 从 seed JSON 别名表查,查不到用注册域字符串)"。`universities` 表 + `student_verifications.university_id` FK + forum school ACL 全部保留。`scripts/university_email_domains.json` 从"白名单"降级为"curated 别名表"。

**Tech Stack:** Python 3.13 + FastAPI + SQLAlchemy + PostgreSQL + pytest

**Spec:** `docs/superpowers/specs/2026-05-19-student-verification-open-ac-uk-design.md`

**Pre-done(已 commit,不要重做):**
- `scripts/university_email_domains.json` — 122 条 unique entries(BCU + Norwich + Lancashire 已加,uwe 已去重)
- `backend/migrations/241_add_missing_universities.sql` — 3 行 INSERT,SQL 文件已就位但**尚未 apply 到任何 DB**

---

## 文件结构

| 文件 | 状态 | 说明 |
|------|------|------|
| `backend/app/university_matcher.py` | **重写** | 删 Aho-Corasick / wildcard / 子域 right-to-left;加 `extract_registrable_ac_uk` + 新 `match_university_by_email` + 简化 `UniversityMatcher` 兼容壳 |
| `backend/tests/test_university_matcher.py` | **新建** | 单元测试(extract / seed loader / match lazy INSERT) |
| `backend/app/main.py` | **不动** | `_university_matcher.initialize(db)` 调用保留,签名不变 |
| `backend/app/student_verification_routes.py` | **不动** | 调用方签名 `match_university_by_email(email, db)` 不变 |
| `backend/migrations/241_add_missing_universities.sql` | 已就位 | 实施时需要在 linktest / prod DB 上跑 |
| `scripts/university_email_domains.json` | 已就位 | 122 条 |

---

## Task 1: TDD `extract_registrable_ac_uk` 辅助函数

**Files:**
- Create: `backend/tests/test_university_matcher.py`
- Modify: `backend/app/university_matcher.py`(加新函数,不删旧代码)

- [ ] **Step 1: 创建测试文件并写第一组测试**

`backend/tests/test_university_matcher.py`:

```python
"""学生认证 university_matcher 单元测试。"""

import pytest
from app.university_matcher import extract_registrable_ac_uk


class TestExtractRegistrableAcUk:
    def test_already_three_part(self):
        assert extract_registrable_ac_uk("bham.ac.uk") == "bham.ac.uk"
        assert extract_registrable_ac_uk("imperial.ac.uk") == "imperial.ac.uk"

    def test_subdomain_collapse(self):
        assert extract_registrable_ac_uk("mail.bcu.ac.uk") == "bcu.ac.uk"
        assert extract_registrable_ac_uk("student.bham.ac.uk") == "bham.ac.uk"
        assert extract_registrable_ac_uk("balliol.ox.ac.uk") == "ox.ac.uk"

    def test_deep_subdomain(self):
        assert extract_registrable_ac_uk("a.b.c.shu.ac.uk") == "shu.ac.uk"

    def test_uppercase_normalized(self):
        assert extract_registrable_ac_uk("Mail.BCU.AC.UK") == "bcu.ac.uk"

    def test_non_ac_uk(self):
        assert extract_registrable_ac_uk("gmail.com") is None
        assert extract_registrable_ac_uk("foo.bar.com") is None
        assert extract_registrable_ac_uk("example.co.uk") is None

    def test_too_short(self):
        assert extract_registrable_ac_uk("ac.uk") is None
        assert extract_registrable_ac_uk("uk") is None
        assert extract_registrable_ac_uk("") is None
```

- [ ] **Step 2: 运行测试验证失败(函数还不存在)**

```powershell
cd backend
pytest tests/test_university_matcher.py::TestExtractRegistrableAcUk -v
```

Expected: 6 个测试全部 ERROR/FAIL,原因 `ImportError: cannot import name 'extract_registrable_ac_uk' from 'app.university_matcher'`。

- [ ] **Step 3: 在 university_matcher.py 顶部加入新函数(保留旧代码)**

在 `backend/app/university_matcher.py` 现有 import 之后,`class UniversityMatcher` 之前插入:

```python
def extract_registrable_ac_uk(domain: str) -> Optional[str]:
    """从 .ac.uk 域名提取注册域(最后 3 段)。

    - mail.bcu.ac.uk → bcu.ac.uk
    - student.bham.ac.uk → bham.ac.uk
    - imperial.ac.uk → imperial.ac.uk(已经是 3 段)
    - gmail.com → None(非 .ac.uk)
    - ac.uk → None(不足 3 段)
    """
    if not domain:
        return None
    parts = domain.lower().split(".")
    if len(parts) < 3 or parts[-2:] != ["ac", "uk"]:
        return None
    return ".".join(parts[-3:])
```

- [ ] **Step 4: 运行测试验证通过**

```powershell
pytest tests/test_university_matcher.py::TestExtractRegistrableAcUk -v
```

Expected: 6 passed。

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_university_matcher.py backend/app/university_matcher.py
git commit -m "feat(student-verification): extract_registrable_ac_uk helper + tests"
```

---

## Task 2: TDD seed alias loader

**Files:**
- Modify: `backend/tests/test_university_matcher.py`(加测试类)
- Modify: `backend/app/university_matcher.py`(加 `_load_seed_aliases`)

- [ ] **Step 1: 加测试类**

在 `backend/tests/test_university_matcher.py` 末尾追加:

```python
from app.university_matcher import _load_seed_aliases


class TestSeedAliasLoader:
    def test_loads_known_entry(self):
        aliases = _load_seed_aliases()
        assert "bham.ac.uk" in aliases
        name, name_cn = aliases["bham.ac.uk"]
        assert name == "University of Birmingham"
        assert name_cn == "伯明翰大学"

    def test_loads_newly_added_entries(self):
        aliases = _load_seed_aliases()
        assert "bcu.ac.uk" in aliases
        assert "norwichuni.ac.uk" in aliases
        assert "lancashire.ac.uk" in aliases

    def test_total_unique_entries(self):
        aliases = _load_seed_aliases()
        assert len(aliases) == 122

    def test_keys_are_registrable_domains(self):
        """seed JSON 里若有 student.gla.ac.uk 这种带子域的 email_domain,
        loader 也要规范化成注册域 gla.ac.uk 当 key。"""
        aliases = _load_seed_aliases()
        # University of Glasgow seed 里 email_domain 是 student.gla.ac.uk
        # 期望 loader 把它 normalize 成 gla.ac.uk
        assert "gla.ac.uk" in aliases
        name, _ = aliases["gla.ac.uk"]
        assert name == "University of Glasgow"
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
pytest tests/test_university_matcher.py::TestSeedAliasLoader -v
```

Expected: `ImportError: cannot import name '_load_seed_aliases'`。

- [ ] **Step 3: 在 university_matcher.py 加 loader 实现**

在 `extract_registrable_ac_uk` 之后插入:

```python
import json
from pathlib import Path

_seed_aliases_cache: Optional[dict] = None


def _load_seed_aliases() -> dict[str, tuple[str, Optional[str]]]:
    """加载 scripts/university_email_domains.json,返回 {注册域 -> (name, name_cn)}。

    - 重复 key 时后者覆盖前者
    - 非 .ac.uk 或异常条目跳过
    - 结果在进程级缓存(_seed_aliases_cache),避免每次磁盘读
    """
    global _seed_aliases_cache
    if _seed_aliases_cache is not None:
        return _seed_aliases_cache

    # backend/app/university_matcher.py → repo root: parents[2]
    json_path = Path(__file__).resolve().parents[2] / "scripts" / "university_email_domains.json"
    if not json_path.exists():
        logger.warning(f"seed JSON 不存在: {json_path}")
        _seed_aliases_cache = {}
        return _seed_aliases_cache

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    aliases: dict[str, tuple[str, Optional[str]]] = {}
    for uni in data:
        email_domain = uni.get("email_domain")
        if not email_domain:
            continue
        registrable = extract_registrable_ac_uk(email_domain)
        if registrable is None:
            continue
        aliases[registrable] = (uni.get("name") or registrable, uni.get("name_cn"))

    _seed_aliases_cache = aliases
    return aliases
```

注:`json` 和 `Path` 在文件顶部 import 区域追加。

- [ ] **Step 4: 运行测试验证通过**

```powershell
pytest tests/test_university_matcher.py::TestSeedAliasLoader -v
```

Expected: 4 passed。如果 `test_total_unique_entries` 显示 != 122,说明 seed JSON 改过,核对一下。

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_university_matcher.py backend/app/university_matcher.py
git commit -m "feat(student-verification): seed JSON alias loader + tests"
```

---

## Task 3: TDD 新 `match_university_by_email` 函数

**Files:**
- Modify: `backend/tests/test_university_matcher.py`(加 DB 集成测试)
- Modify: `backend/app/university_matcher.py`(新增/替换 match 函数)

- [ ] **Step 1: 加 DB 集成测试**

在 test 文件末尾追加:

```python
from app import models


@pytest.fixture(autouse=True)
def _reset_seed_cache():
    """每个测试前重置 seed 缓存,避免测试间状态污染。"""
    import app.university_matcher as m
    m._seed_aliases_cache = None
    yield


class TestMatchUniversityByEmail:
    def test_invalid_email_format(self, db):
        from app.university_matcher import match_university_by_email
        assert match_university_by_email("not-an-email", db) is None
        assert match_university_by_email("", db) is None
        assert match_university_by_email(None, db) is None

    def test_non_ac_uk_rejected(self, db):
        from app.university_matcher import match_university_by_email
        assert match_university_by_email("user@gmail.com", db) is None
        assert match_university_by_email("user@example.com", db) is None

    def test_existing_registrable_returns_existing_row(self, db):
        from app.university_matcher import match_university_by_email
        db.add(models.University(
            name="University of Birmingham",
            name_cn="伯明翰大学",
            email_domain="bham.ac.uk",
            domain_pattern="@*.bham.ac.uk",
            is_active=True,
        ))
        db.flush()

        uni = match_university_by_email("alice@student.bham.ac.uk", db)
        assert uni is not None
        assert uni.email_domain == "bham.ac.uk"
        assert uni.name == "University of Birmingham"

    def test_lazy_insert_uses_seed_alias(self, db):
        """bcu.ac.uk 在 seed JSON 里但 DB 没有 → INSERT 用 curated 中文名"""
        from app.university_matcher import match_university_by_email
        uni = match_university_by_email("alice@mail.bcu.ac.uk", db)
        assert uni is not None
        assert uni.email_domain == "bcu.ac.uk"
        assert uni.name == "Birmingham City University"
        assert uni.name_cn == "伯明翰城市大学"

    def test_lazy_insert_unknown_domain_uses_fallback_name(self, db):
        """注册域既不在 DB 也不在 seed → INSERT,name = 注册域,name_cn = NULL"""
        from app.university_matcher import match_university_by_email
        uni = match_university_by_email("alice@dept.imaginary.ac.uk", db)
        assert uni is not None
        assert uni.email_domain == "imaginary.ac.uk"
        assert uni.name == "imaginary.ac.uk"
        assert uni.name_cn is None

    def test_same_registrable_grouped(self, db):
        """同注册域不同子域邮箱 → 同 university_id(兜底:同 .ac.uk 同校)"""
        from app.university_matcher import match_university_by_email
        uni1 = match_university_by_email("alice@x.imaginary2.ac.uk", db)
        uni2 = match_university_by_email("bob@y.imaginary2.ac.uk", db)
        assert uni1 is not None and uni2 is not None
        assert uni1.id == uni2.id
        assert uni1.email_domain == "imaginary2.ac.uk"
```

- [ ] **Step 2: 运行测试验证(部分会失败、部分意外通过)**

```powershell
pytest tests/test_university_matcher.py::TestMatchUniversityByEmail -v
```

Expected: 旧 `match_university_by_email` 还在,会有混合结果。但 lazy INSERT / 注册域 fallback 的 case 一定失败(旧逻辑没有 lazy INSERT)。

- [ ] **Step 3: 在 university_matcher.py 加新的 match 函数(覆盖旧的)**

把旧的 `def match_university_by_email(email: str, db=None) -> Optional[models.University]:`(原 141-157 行)**整段删除**,替换为:

```python
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


def match_university_by_email(email: str, db: Session) -> Optional[models.University]:
    """根据 .ac.uk 邮箱匹配或自动创建大学行。

    1. 不是 .ac.uk 后缀 → None
    2. 提取注册域(最后 3 段)→ SELECT universities
    3. 命中 → 返回
    4. 不命中 → INSERT(name 从 seed JSON 别名表查;查不到用注册域字符串作 name)
    5. 并发 IntegrityError → re-SELECT 兜底
    """
    if not email or "@" not in email:
        return None
    _, _, domain = email.partition("@")
    domain = domain.strip().lower()

    registrable = extract_registrable_ac_uk(domain)
    if registrable is None:
        return None

    uni = db.query(models.University).filter(
        models.University.email_domain == registrable
    ).first()
    if uni:
        return uni

    aliases = _load_seed_aliases()
    name, name_cn = aliases.get(registrable, (registrable, None))

    uni = models.University(
        email_domain=registrable,
        name=name,
        name_cn=name_cn,
        domain_pattern=f"@*.{registrable}",  # 占位,新算法不读
        is_active=True,
    )
    db.add(uni)
    try:
        db.commit()
        db.refresh(uni)
    except IntegrityError:
        db.rollback()
        uni = db.query(models.University).filter(
            models.University.email_domain == registrable
        ).first()
    return uni
```

Note: `Session` 和 `IntegrityError` 加进 import 区。

- [ ] **Step 4: 运行 match 测试验证全部通过**

```powershell
pytest tests/test_university_matcher.py::TestMatchUniversityByEmail -v
```

Expected: 6 passed。

- [ ] **Step 5: 运行**全部** university_matcher 测试,确认没回退**

```powershell
pytest tests/test_university_matcher.py -v
```

Expected: 16 passed(Task1 的 6 + Task2 的 4 + Task3 的 6)。

- [ ] **Step 6: Commit**

```bash
git add backend/tests/test_university_matcher.py backend/app/university_matcher.py
git commit -m "feat(student-verification): lazy INSERT match_university_by_email + tests"
```

---

## Task 4: 清理 UniversityMatcher 类残留 + 删除 Aho-Corasick

**Files:**
- Modify: `backend/app/university_matcher.py`(精简 UniversityMatcher 类,删 try/except pyahocorasick import,删旧 match / initialize 逻辑)

- [ ] **Step 1: 替换 UniversityMatcher 类为兼容壳**

把原 `class UniversityMatcher:`(行号现已变,搜索关键字)整体 + 紧跟的 `_university_matcher = UniversityMatcher()` 替换为:

```python
class UniversityMatcher:
    """已废弃的兼容壳,仅为 main.py 启动钩子保留 initialize()。

    Lazy DB matching 不再需要内存缓存。真实匹配请直接调用模块级
    `match_university_by_email(email, db)`。
    """

    _initialized = False

    def initialize(self, db: Session) -> None:
        # 触发 seed 加载,顺便对外部观感"启动时已经准备好"
        _load_seed_aliases()
        self._initialized = True
        logger.info(
            f"大学匹配器初始化完成 (open-by-suffix 模式,seed 别名 "
            f"{len(_load_seed_aliases())} 条)"
        )

    def match(self, email: str) -> Optional[models.University]:
        raise RuntimeError(
            "UniversityMatcher.match() 已废弃。请直接调用 "
            "app.university_matcher.match_university_by_email(email, db)"
        )


_university_matcher = UniversityMatcher()
```

- [ ] **Step 2: 删除 pyahocorasick 相关代码**

文件顶部 try/except 块:

```python
try:
    from pyahocorasick import Automaton
    HAS_AHOCORASICK = True
except ImportError:
    HAS_AHOCORASICK = False
    Automaton = None
```

整段删除。同时把残留的 `from app import models` / `import threading` / `import logging` 这些 import 该留留、该删删。

最终 `university_matcher.py` 应该只包含:
- imports: `import json` / `import logging` / `from pathlib import Path` / `from typing import Optional` / `from sqlalchemy.exc import IntegrityError` / `from sqlalchemy.orm import Session` / `from app import models`
- module-level: `logger = logging.getLogger(__name__)`、`_seed_aliases_cache`
- 函数: `extract_registrable_ac_uk` / `_load_seed_aliases` / `match_university_by_email`
- 类 + 单例: `UniversityMatcher` / `_university_matcher`

- [ ] **Step 3: 运行所有测试 + lint**

```powershell
pytest tests/test_university_matcher.py -v
python -c "from app.university_matcher import extract_registrable_ac_uk, _load_seed_aliases, match_university_by_email, _university_matcher, UniversityMatcher; print('imports OK')"
```

Expected: 16 passed,import 输出 `imports OK`。

- [ ] **Step 4: 跑一遍 main.py startup 路径冒烟(可选 — 仅本地有 DB 时)**

```powershell
python -c "
from app.database import SessionLocal
from app.university_matcher import _university_matcher
db = SessionLocal()
try:
    _university_matcher.initialize(db)
finally:
    db.close()
"
```

Expected: 控制台打印 "大学匹配器初始化完成 (open-by-suffix 模式,seed 别名 122 条)",无 Exception。

- [ ] **Step 5: Commit**

```bash
git add backend/app/university_matcher.py
git commit -m "refactor(student-verification): drop Aho-Corasick / wildcard / right-to-left subdomain — UniversityMatcher 降为兼容壳"
```

---

## Task 5: 部署 + 端到端冒烟(linktest)

**Files:** 无代码改动,只跑 migration + 推 main + 调用 API 验证

- [ ] **Step 1: 把代码推到 main**

```bash
git push origin main
```

Expected: push 成功。Railway 收到 webhook 后开始 redeploy linktest。

- [ ] **Step 2: 在 linktest DB 上跑 migration 241**

到 Railway dashboard → linktest service → "Run command" 或本地配 `DATABASE_URL=<linktest>` 跑:

```bash
psql $LINKTEST_DATABASE_URL -f backend/migrations/241_add_missing_universities.sql
```

Expected: 输出 3 个 `INSERT 0 1`(或如果之前已加过 BCU,会有部分 `INSERT 0 0` ON CONFLICT)。

- [ ] **Step 3: 等 Railway redeploy 完成,启动日志确认匹配器初始化输出**

观察 linktest 启动日志,期望出现:

```
大学匹配器初始化完成 (open-by-suffix 模式,seed 别名 122 条)
```

如果还出现"加载了 X 所大学 (使用Aho-Corasick算法)" 旧日志,说明 deploy 还没完成或代码未推上去。

- [ ] **Step 4: 用 BCU 邮箱发真实请求验证**

```bash
curl -X POST 'https://linktest.up.railway.app/api/student-verification/submit' \
  -H "Authorization: Bearer <test-user-token>" \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke-test@mail.bcu.ac.uk"}'
```

Expected: HTTP 200,返回 verification 对象。`SELECT * FROM universities WHERE email_domain = 'bcu.ac.uk'`(linktest)有一行,name = Birmingham City University。

- [ ] **Step 5: 用一个全新 .ac.uk 域名验证 lazy INSERT 路径**

```bash
curl -X POST 'https://linktest.up.railway.app/api/student-verification/submit' \
  -H "Authorization: Bearer <test-user-token>" \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke-test@dept.lazy-test.ac.uk"}'
```

Expected: HTTP 200。`SELECT * FROM universities WHERE email_domain = 'lazy-test.ac.uk'` 多一行,name = 'lazy-test.ac.uk',name_cn = NULL。

清理:`DELETE FROM universities WHERE email_domain = 'lazy-test.ac.uk';`(如果生成了 student_verification 测试行也清掉)。

- [ ] **Step 6: 用非 .ac.uk 邮箱验证拒绝路径**

```bash
curl -X POST 'https://linktest.up.railway.app/api/student-verification/submit' \
  -H "Authorization: Bearer <test-user-token>" \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke-test@gmail.com"}'
```

Expected: HTTP 400,response 包含 `"error": "INVALID_EMAIL_DOMAIN"`。

- [ ] **Step 7: 在 prod DB 跑 migration 241**

```bash
psql $PROD_DATABASE_URL -f backend/migrations/241_add_missing_universities.sql
```

Expected: 3 个 `INSERT 0 1`。

- [ ] **Step 8: 等 Railway prod 自动 deploy 完成,启动日志同样确认**

期望同 Step 3 的日志。

- [ ] **Step 9: prod 上用 BCU 邮箱重发一次原始失败请求验证修复**

让原始报错用户(`yujun.liu@mail.bcu.ac.uk`)重试提交,或:

```bash
curl -X POST 'https://api.link2ur.com/api/student-verification/submit' \
  -H "Authorization: Bearer <user-token>" \
  -H 'Content-Type: application/json' \
  -d '{"email":"yujun.liu@mail.bcu.ac.uk"}'
```

Expected: HTTP 200,流程进入 pending 等待邮件验证。

---

## Spec 覆盖检查

| Spec 章节 | 对应 Task |
|----------|-----------|
| §3.1 匹配算法 | Task 1 (extract) + Task 3 (match) |
| §3.2 Seed JSON 改造 | Task 2 (loader) |
| §3.3 数据迁移 | Task 5 Step 2 / Step 7 |
| §3.4 Seed JSON 文件清洗 | 已 commit `cd26ab7b4`(实施前) |
| §3.5 代码改动 — university_matcher.py | Task 3 + Task 4 |
| §3.5 代码改动 — main.py | 无改动(签名兼容) |
| §3.6 错误码 / 文案 | Task 3 Step 3 自动满足(非 .ac.uk → None → 路由层返回 INVALID_EMAIL_DOMAIN) |
| §3.7 自动 INSERT 并发安全 | Task 3 Step 3(IntegrityError try/except) |
| §3.8 Forum School ACL | 无改动(spec 明确说"不受影响") |
| §4.1 单元测试 | Task 1 + Task 2 + Task 3 |
| §4.2 手测 | Task 5 |
| §5 部署顺序 | Task 5 Step 1-9 |

## 风险点 / 部署前确认

1. **conftest 的 `db` fixture 要求真实 PostgreSQL**(不能用 SQLite,因为 ON CONFLICT 语法对应 Postgres dialect)。本地无 `TEST_DATABASE_URL` 时 Task 3 / Task 4 单元测试会 skip。CI 上应已配。
2. **migration 241 必须 prod 跑之前先在 linktest 验证**(参考 memory: 加列 migration 必须先跑 DB 再 push;此处虽然是 INSERT 不是加列,顺序同样保留)。
3. **`models.University.email_domain` UNIQUE 约束**已经存在(migration 030),IntegrityError 处理路径依赖它 — 实施前确认。
