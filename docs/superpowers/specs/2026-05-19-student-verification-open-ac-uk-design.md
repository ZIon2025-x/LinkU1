# 学生认证从白名单切换到 `.ac.uk` open-by-suffix

**Date**: 2026-05-19
**Status**: Approved (pending implementation plan)
**Trigger**: 2026-05-19 BCU 学生 `yujun.liu@mail.bcu.ac.uk` 提交学生认证被拒,
排查发现 seed JSON 缺 BCU 这一所学校。后续 121 条 seed 系统审计结论:

- 没有"官网域当邮件域"的错条目(Birmingham `bham.ac.uk` 等都是对的)
- 但有 3 个机构缺漏 / 不完整需补:
  1. **Birmingham City University** (post-92 学校,完全漏录)
  2. **Norwich University of the Arts** 正在 `nua.ac.uk` → `norwichuni.ac.uk`
     过渡,seed 只有旧域
  3. **University of Central Lancashire** 已 rebrand 为 University of
     Lancashire,新域 `lancashire.ac.uk`,seed 只有旧域 `uclan.ac.uk`

同时本期顺势把整个验证机制改成 open-by-suffix,避免未来再被"漏录"事故反复拖累。

## 1. 问题

当前学生认证流程:
1. 用户提交学生邮箱 → `match_university_by_email()` 在 `universities` 表(seed
   JSON 预装 121 条)里做精确 / 子域 / 通配符匹配。
2. 命中 → 创建 `student_verifications` 行(状态 pending → verified)。
3. 未命中 → 返回 `INVALID_EMAIL_DOMAIN` 400。

问题:
- 每次出现 seed 未覆盖的学校(BCU / Norwich / Lancashire 这种新名 / rebrand),
  都要 **手动改 seed → 跑 migration → 重启 backend 让 matcher 重读缓存**,运营
  负担大,而且只有用户被拒之后才发现。
- 现行 matcher 三种匹配方式(精确 / 子域 / 通配符)逻辑复杂、用 Aho-Corasick 加速,
  对一个低频操作来说是过度工程,且**内存缓存**模式让 seed/DB 改动后必须重启服务。
- BCU 这次直接被拒,用户体验差。

## 2. 决策

**收紧条件**:邮箱后缀必须是 `.ac.uk`。
**放开校验**:满足后缀就接受,学校身份由**注册域**作为唯一 key。

> "注册域" 定义:邮箱域名按 `.` 分段后**取最后 3 段** —— 也即"紧贴 `ac.uk` 的那一
> 段" + `ac.uk`。例如:
> - `mail.bcu.ac.uk` → `bcu.ac.uk`
> - `student.bham.ac.uk` → `bham.ac.uk`
> - `balliol.ox.ac.uk` → `ox.ac.uk`
> - `imperial.ac.uk` → `imperial.ac.uk`(本身就是 3 段)

`universities` 表保留(`student_verifications.university_id` FK + migration 032 的
forum school ACL 仍依赖它),改为**懒加载**:遇到未见过的注册域时自动 INSERT 一行。

## 3. 设计

### 3.1 匹配算法(替换 `university_matcher.py`)

```python
def match_university_by_email(email: str, db: Session) -> Optional[University]:
    # 1. 验证格式
    if "@" not in email:
        return None
    local, _, domain = email.partition("@")
    domain = domain.lower()

    # 2. 必须 .ac.uk 后缀
    if not domain.endswith(".ac.uk"):
        return None

    # 3. 提取注册域(最后 3 段,见上文"注册域定义")
    #    yujun.liu@mail.bcu.ac.uk → mail.bcu.ac.uk → bcu.ac.uk
    #    alice@balliol.ox.ac.uk   → balliol.ox.ac.uk → ox.ac.uk
    registrable = extract_registrable_ac_uk(domain)
    if registrable is None:
        return None  # 极端情况:仅 ".ac.uk" 本身

    # 4. SELECT or INSERT
    uni = db.query(University).filter(University.email_domain == registrable).first()
    if uni:
        return uni

    name, name_cn = _seed_alias_lookup(registrable)  # seed JSON 仍作别名
    uni = University(
        email_domain=registrable,
        name=name or registrable,
        name_cn=name_cn,
        domain_pattern=f"@*.{registrable}",  # 仅占位,新算法不读
        is_active=True,
    )
    db.add(uni)
    db.commit()
    db.refresh(uni)
    return uni


def extract_registrable_ac_uk(domain: str) -> Optional[str]:
    """从 .ac.uk 域名提取注册域 = 最后 3 段(见上文"注册域定义")。"""
    parts = domain.split(".")
    if len(parts) < 3 or parts[-2:] != ["ac", "uk"]:
        return None
    return ".".join(parts[-3:])
```

### 3.2 Seed JSON 改造

`scripts/university_email_domains.json` 保留,用途从"白名单"变成"curated 别名表":
- 命中时提供漂亮的中英文 name
- 未命中时占位名 = 注册域字符串

启动时不再加载到内存(matcher 不再用 Aho-Corasick)。Seed 改读时机:
- **方案 A**(选定):启动时一次性把 seed JSON 读成 `dict[registrable_domain → (name, name_cn)]`
  存在内存,匹配时查这个 dict 拿别名。文件改动后需重启 backend。
- 方案 B(不选):每次 INSERT 临时 open 读 JSON。频次低但 IO 浪费。

### 3.3 数据迁移 (`backend/migrations/241_add_missing_universities.sql`)

```sql
-- 0. 去掉 name UNIQUE 约束 — rebrand 场景(Norwich/UCLan)需要同名两行,UNIQUE 反而碍事
--    重名防护改靠 email_domain UNIQUE 兜底
ALTER TABLE universities DROP CONSTRAINT IF EXISTS universities_name_key;

-- 1. 补 3 条缺漏:BCU + Norwich 新域 + Lancashire 新域
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Birmingham City University', '伯明翰城市大学', 'bcu.ac.uk', '@*.bcu.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Norwich University of the Arts', '诺里奇艺术大学', 'norwichuni.ac.uk', '@*.norwichuni.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('University of Lancashire', '兰开夏大学', 'lancashire.ac.uk', '@*.lancashire.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;
```

注:Norwich 两行(`nua.ac.uk` 和 `norwichuni.ac.uk`)同 `name="Norwich University of the Arts"`,
学生收到的认证邮件和 API 响应显示统一干净。`models.py:3086` 也去掉了 `unique=True` 让模型
和 schema 一致。

注:其他 118 条 seed entry 经审计**全部正确**(包括 Birmingham `bham.ac.uk`、post-92
学校用 root 域名 + 学生子域邮箱的情况:Sheffield Hallam `shu.ac.uk` → 学生
`@stu.shu.ac.uk`,新算法走"提取注册域 → SELECT seed"路径,直接命中)。**不做主动
修改**。Glamorgan(2013 年并入 USW)等 historical 条目保留 dormant,无害。

### 3.4 Seed JSON 文件清洗(代码内,与 DB migration 并行)

`scripts/university_email_domains.json` 改动:
- 追加 3 条:
  - `bcu.ac.uk` — Birmingham City University
  - `norwichuni.ac.uk` — Norwich University of the Arts(并存于旧 `nua.ac.uk`)
  - `lancashire.ac.uk` — University of Lancashire(并存于旧 `uclan.ac.uk`)
- 去重 1 条:`uwe.ac.uk` 原本有两行(`University of the West of England` 和
  `University of West of England, Bristol`),保留前者删除后者
- 最终 122 条,unique 122

其他条目不动。

### 3.5 代码改动

| 文件 | 变化 |
|------|------|
| `app/university_matcher.py` | 整体重写。删 Aho-Corasick / wildcard / right-to-left subdomain 逻辑,只留新算法。`UniversityMatcher` 类降级为简单的 seed 别名加载器,匹配走 DB 直接 SELECT/INSERT。 |
| `app/main.py:1507-1508` startup | `_university_matcher.initialize(db)` 改成 seed JSON 加载,不再加载 universities 表。 |
| `app/student_verification_routes.py` | 错误消息保留 `INVALID_EMAIL_DOMAIN`,但触发条件实际只剩"不是 `.ac.uk`"。 |
| `scripts/init_universities.py` | 不需改,保留作可选运维工具(强制按 seed 全量 sync)。 |

### 3.6 错误码 / 文案

- 输入不是 `.ac.uk`:仍返回 `INVALID_EMAIL_DOMAIN` + "邮箱必须使用学校的 `.ac.uk` 邮箱"
- 极端边界(仅 `.ac.uk` 没注册域):同上
- 新模型下基本不会出现"学校不在支持列表"这条文案,但保留兜底

### 3.7 自动 INSERT 的并发安全

懒加载方案下,两个学生同时第一次用同一新域名提交时可能竞态。处理:
- DB 层:`universities.email_domain` 是 UNIQUE(030 migration)
- 应用层:`try: db.add + commit; except IntegrityError: db.rollback(); 重新 SELECT by email_domain`

`name` 不再 UNIQUE(241 migration 去掉),所以 IntegrityError 唯一来源就是 email_domain
race,re-SELECT 一定能拿到赢家行。

### 3.8 Forum School ACL(migration 032)

不受影响。`forum_categories.allowed_university_id` 仍按 `university_id` 工作。新学校
被懒加载进 universities 表后,默认**不在任何 school-restricted 板块的白名单里**,这
是期望行为(新学校要被允许访问限定板块需要 admin 手动配置)。

### 3.9 风险

- **JANET 之外的 `.ac.uk`**:极少数研究机构(`stfc.ac.uk`、`nerc.ac.uk` 等)。
  当前**不做黑名单**,等出现实际滥用再加。
- **没有显式 audit**:未在 seed 里的注册域会"静默 INSERT"。Admin 后台想感知新学校
  可以加一个"`name_cn IS NULL` 的 universities 行"过滤视图,**不在本期 scope**。
- **机构 rebrand / 域名迁移**(如 NUA / UCLan):新算法直接吃旧+新两个注册域分别
  作为两行 universities,**`name` UNIQUE 已去**(migration 241 Step 0),两行可共享 name,
  学生邮件 / API 显示统一。Admin 后续可合并 / 标记 dormant。
- **`name` UNIQUE 去掉的副作用**:admin 现在手抖建重名学校 DB 不会拦,要靠 admin UI 自己
  把关。但 email_domain UNIQUE 仍在,真正的"同校"防重复靠它兜底。

### 3.10 不做的事(YAGNI)

- 不做学校名校验 / 查重(自愈机制 + admin 后补)
- 不做 WebSearch / PSL 动态查中英文名(过度设计)
- 不做用户提交学校名表单字段
- 不做 121 条 seed 全量主动审计(已一次性审计完;新模型自愈兜底)
- 不删 `universities.domain_pattern` 列(留作旧数据,不读)

## 4. 测试策略

### 4.1 单元测试

`tests/test_university_matcher.py`:
- `extract_registrable_ac_uk` 正例:
  - `mail.bcu.ac.uk` → `bcu.ac.uk`
  - `student.bham.ac.uk` → `bham.ac.uk`
  - `balliol.ox.ac.uk` → `ox.ac.uk`
  - `imperial.ac.uk` → `imperial.ac.uk`(已经是注册域)
- `extract_registrable_ac_uk` 反例:
  - `gmail.com` → None
  - `foo.bar.com` → None
  - `ac.uk` → None(只有 2 段,不足 3 段)
  - `xyz.ac.uk` → `xyz.ac.uk`(刚好 3 段,本身就是注册域,允许)

- `match_university_by_email` 集成:
  - 已存在的注册域 → 直接返回
  - 新注册域 → INSERT + 返回
  - 并发模拟:两个 session 同时插入同一域名 → 一个成功一个 ON CONFLICT 静默,最终
    只有一行

### 4.2 手测

实施后在 linktest 上跑:
1. `POST /api/student-verification/submit` with `@mail.bcu.ac.uk` → 200,
   universities 表多一行 `bcu.ac.uk`(seed 已有,name 用 curated 中文)
2. 同上 `@student.bham.ac.uk` → 200,如果 `bham.ac.uk` 还没在表里则 INSERT,name
   用 seed 别名 "University of Birmingham"
3. 用一个未知 `.ac.uk`(比如 `@example.dummy.ac.uk`,虽然不真实)→ 200,
   universities 多一行 `dummy.ac.uk`(name = 'dummy.ac.uk', name_cn = NULL)
4. 用 `@gmail.com` → 400 INVALID_EMAIL_DOMAIN

## 5. 部署顺序

1. **先**在 linktest DB 跑 migration 241 → 验证 → 推 main 到 linktest
2. linktest 跑完测试 case → **再**在 prod DB 跑 migration 241 → 自动 deploy
3. 不需要后端重启来"重读白名单":新 matcher 直接走 DB SELECT,不依赖内存缓存

## 6. 已确认的设计点

- ✅ 注册域 = `.ac.uk` 域名最后 3 段(`bham.ac.uk`、`ox.ac.uk` 这种)
- ✅ universities 表保留 + 懒加载
- ✅ Seed JSON 作为别名表,未命中用注册域字符串占位
- ✅ Migration 241 = BCU + Norwich 新域 + Lancashire 新域 共 3 条 INSERT
- ✅ `.ac.uk` 全开(含研究机构),无黑名单

## 7. 文件清单(预期改动)

```
backend/
├── app/university_matcher.py                       # 重写
├── app/main.py                                     # 调整 startup 初始化
├── app/student_verification_routes.py              # 微调错误文案(可选)
├── migrations/241_add_missing_universities.sql     # 新增(已写)
└── tests/test_university_matcher.py                # 新增 / 重写

scripts/
└── university_email_domains.json                   # 已追加 BCU + Norwich + Lancashire

docs/superpowers/specs/
└── 2026-05-19-student-verification-open-ac-uk-design.md  # 本文
```
