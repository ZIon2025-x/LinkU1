# 普通用户主页 · 个人服务 Section 实现 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `user_profile_view`（他人公开主页）上展示该用户发布的「个人服务」（`task_expert_services` 表中 `service_type='personal'` + `owner_type='user'` 的行），覆盖老用户视角和陌生人视角两种场景，服务为空时整个 section 自动隐藏。

**Architecture:**
- 后端复用 `personal_service_routes._serialize_service` 的字段定义思路，扩展 `GET /profile/{user_id}` 的 dict 响应增加 `personal_services` key（不引入新 Pydantic schema、无 migration）。
- Flutter 在 `data/models/user.dart` 加 `UserProfilePersonalService` 数据类并扩展 `UserProfileDetail.fromJson`；新建独立 widget `PersonalServicesSection`（`features/profile/views/widgets/personal_services_section.dart`），由 `user_profile_view.dart` 引用。Widget 内部判空 → 服务为空时返回 `SizedBox.shrink()`，不留空白。
- 把 section 做成独立 public widget（而不是 view 的私有方法）的目的：方便用 `flutter_test` 直接对它写 widget test，不需要绕开 `UserProfileView` 内部 `BlocProvider(create: ...)` 自建独立 bloc 的复杂度。

**Tech Stack:** FastAPI + SQLAlchemy（同步 Session）· Flutter + BLoC · ARB l10n（en/zh/zh_Hant）· pytest · flutter_test + bloc_test

**Out of scope（明确不做）:**
- 不做新的「按 user_id 取 personal services」独立 endpoint —— 直接挂在 profile API 上
- 不改 `task_expert_services` 表结构（无 migration）
- 不做服务详情页跳转的全功能集成 —— 只做「点击跳转」占位（指向已有的 `/services/:id` 路由，如不存在则做 SnackBar 提示）
- 不引入 review tags / featured review 等之前讨论但被砍掉的功能

---

## File Structure

| 文件 | 动作 | 责任 |
|------|------|------|
| `backend/app/routes/profile_routes.py` | 修改 | `user_profile()` 内查询 `task_expert_services` 并加进返回 dict |
| `backend/tests/test_profile_routes_personal_services.py` | 创建 | 验证 endpoint 返回正确结构（自带 TestClient + `get_db` override fixture） |
| `link2ur/lib/data/models/user.dart` | 修改 | 加 `UserProfilePersonalService` 类，扩展 `UserProfileDetail.fromJson` |
| `link2ur/lib/features/profile/views/widgets/personal_services_section.dart` | 创建 | 独立 widget：渲染服务列表、空列表折叠为 `SizedBox.shrink` |
| `link2ur/lib/features/profile/views/user_profile_view.dart` | 修改 | import 并在 children 列表中插入 `PersonalServicesSection` |
| `link2ur/lib/l10n/app_en.arb` | 修改 | 加 4 个新 key（profilePersonalServices / Count / PriceFrom / Negotiable） |
| `link2ur/lib/l10n/app_zh.arb` | 修改 | 同上 |
| `link2ur/lib/l10n/app_zh_Hant.arb` | 修改 | 同上 |
| `link2ur/test/data/models/user_profile_personal_services_test.dart` | 创建 | 单元测试 `UserProfileDetail.fromJson` 解析 personal_services |
| `link2ur/test/features/profile/personal_services_section_test.dart` | 创建 | Widget test：非空渲染 / 空隐藏 / 议价文案 |

---

## Pre-flight

- [ ] **Step 0: 确认环境**

  ```bash
  cd /f/python_work/LinkU
  git status   # 应在 main 分支，无未提交变动（或仅 mockup 文件）
  ```

  Per memory：solo 项目直接推 main，不开 feature 分支。

  Flutter 环境（PowerShell）：
  ```powershell
  $env:PATH = "F:\flutter\bin;" + $env:PATH
  $env:PUB_CACHE = "F:\DevCache\.pub-cache"
  flutter --version
  ```

---

## Task 1: 后端 — 写失败测试（API 应返回 personal_services key）

**Files:**
- Create: `backend/tests/test_profile_routes_personal_services.py`

- [ ] **Step 1: 写测试**

  > 关键约束（来自 codebase 实际情况）：
  > - `backend/tests/conftest.py` 只暴露 `db` fixture（rollback-style transaction），**没有 `client` fixture**，需要本测试自己建 TestClient 并 override `get_db` dependency
  > - User 模型的密码列叫 `hashed_password`（不是 `password_hash`）
  > - profile endpoint 装饰了 `@cache_response(ttl=300)`；测试间用不同 user_id 隔离，避免缓存命中

  ```python
  # backend/tests/test_profile_routes_personal_services.py
  """验证 GET /profile/{user_id} 返回 personal_services 字段。"""
  import pytest
  from fastapi.testclient import TestClient
  from sqlalchemy.orm import Session

  from app.main import app
  from app.database import get_db
  from app.models import TaskExpertService, User


  @pytest.fixture
  def client(db: Session) -> TestClient:
      """TestClient with get_db overridden to share fixture session.

      Endpoint creates its own session via Depends(get_db) by default;
      override to reuse our fixture's transactional session so writes are visible.
      """
      def _override_get_db():
          try:
              yield db
          finally:
              pass  # 不 close，让 fixture 控制生命周期

      app.dependency_overrides[get_db] = _override_get_db
      try:
          yield TestClient(app)
      finally:
          app.dependency_overrides.pop(get_db, None)


  @pytest.fixture
  def user_with_services(db: Session) -> User:
      """创建一个用户 + 2 条 active personal services + 1 条 inactive."""
      user = User(
          id="00000099",
          name="测试用户",
          email="ps_test_99@example.com",
          hashed_password="x",
          user_level="normal",
      )
      db.add(user)
      db.flush()

      db.add(TaskExpertService(
          owner_type="user",
          owner_id=user.id,
          user_id=user.id,
          service_type="personal",
          service_name="家教 · 小学数学",
          description="UCL 在读，可上门或线上",
          category="tutoring",
          base_price=15.0,
          currency="GBP",
          pricing_type="fixed",
          location_type="both",
          status="active",
          display_order=0,
      ))
      db.add(TaskExpertService(
          owner_type="user",
          owner_id=user.id,
          user_id=user.id,
          service_type="personal",
          service_name="代取快递",
          description="伦敦市内 30 分钟响应",
          category="errand",
          base_price=8.0,
          currency="GBP",
          pricing_type="fixed",
          location_type="in_person",
          status="active",
          display_order=1,
      ))
      # inactive 服务，不应被返回
      db.add(TaskExpertService(
          owner_type="user",
          owner_id=user.id,
          user_id=user.id,
          service_type="personal",
          service_name="已下架",
          description="should not appear",
          category="other",
          base_price=10.0,
          currency="GBP",
          pricing_type="fixed",
          location_type="online",
          status="inactive",
          display_order=2,
      ))
      db.flush()  # 用 flush 而非 commit, 配合 conftest 的 rollback 隔离
      return user


  def test_profile_returns_personal_services(client: TestClient, user_with_services: User):
      resp = client.get(f"/profile/{user_with_services.id}")
      assert resp.status_code == 200, resp.text
      data = resp.json()
      assert "personal_services" in data, f"keys: {list(data.keys())}"
      services = data["personal_services"]
      assert isinstance(services, list)
      assert len(services) == 2  # active only, inactive filtered
      assert services[0]["service_name"] == "家教 · 小学数学"  # display_order=0 在前
      assert services[1]["service_name"] == "代取快递"
      # 字段完整性
      first = services[0]
      for key in ("id", "service_name", "category", "base_price", "currency",
                  "pricing_type", "location_type", "images", "status"):
          assert key in first, f"missing {key} in {first}"


  def test_profile_returns_empty_personal_services_when_user_has_none(
      client: TestClient, db: Session
  ):
      # 用不同 user_id 避免 cache_response 与上一个测试串台
      user = User(
          id="00000098",
          name="无服务用户",
          email="nops_98@example.com",
          hashed_password="x",
          user_level="normal",
      )
      db.add(user)
      db.flush()

      resp = client.get(f"/profile/{user.id}")
      assert resp.status_code == 200, resp.text
      data = resp.json()
      assert data["personal_services"] == []
  ```

  > 如果运行时发现 `@cache_response` 在没有 Redis 的本地环境抛异常或 cache 跨测试串台，回退方案：在 `app.main` 之前 `monkeypatch.setattr("app.cache.cache_response", lambda **kw: (lambda f: f))` 直接 noop 装饰器。这一行需要从实测错误中确认是否需要。

- [ ] **Step 2: 运行测试，确认失败**

  ```bash
  cd backend
  pytest tests/test_profile_routes_personal_services.py -v
  ```

  Expected: 两个测试都失败，`assert "personal_services" in data` 失败（因为 endpoint 还没返回这个字段）。

- [ ] **Step 3: Commit 失败测试**

  ```bash
  git add backend/tests/test_profile_routes_personal_services.py
  git commit -m "test(profile): assert /profile/{user_id} returns personal_services field"
  ```

---

## Task 2: 后端 — 在 profile_routes 里查询并返回 personal_services

**Files:**
- Modify: `backend/app/routes/profile_routes.py:430-499`（在已有返回 dict 里加新 key）

- [ ] **Step 1: 在 user_profile() 函数内、`return {` 之前，加查询代码**

  在 `profile_routes.py` 的 `user_profile()` 函数中，找到「获取用户已售闲置物品」那段（约 418-430 行），在它之后、`return {` 之前插入：

  ```python
      # 获取用户的「个人服务」(service_type='personal', 仅 active, 按 display_order 升序最多 5 条)
      from app.models import TaskExpertService
      personal_service_rows = (
          db.query(TaskExpertService)
          .filter(
              TaskExpertService.owner_type == "user",
              TaskExpertService.owner_id == user_id,
              TaskExpertService.service_type == "personal",
              TaskExpertService.status == "active",
          )
          .order_by(
              TaskExpertService.display_order.asc(),
              TaskExpertService.created_at.desc(),
          )
          .limit(5)
          .all()
      )

      def _serialize_personal_service(s: TaskExpertService) -> dict:
          return {
              "id": s.id,
              "service_name": s.service_name,
              "service_name_en": s.service_name_en,
              "service_name_zh": s.service_name_zh,
              "description": s.description,
              "description_en": s.description_en,
              "description_zh": s.description_zh,
              "category": s.category,
              "base_price": float(s.base_price) if s.base_price else 0.0,
              "currency": s.currency or "GBP",
              "pricing_type": s.pricing_type or "fixed",
              "location_type": s.location_type or "online",
              "location": s.location,
              "images": s.images or [],
              "status": s.status,
              "view_count": s.view_count or 0,
              "application_count": s.application_count or 0,
          }
  ```

  > 不复用 `personal_service_routes._serialize_service` 是因为：(1) 那个 helper 含 owner display_name/avatar 等不必要字段；(2) 跨模块 import 会让 cache 失效逻辑更难追；(3) 这里只取公开展示字段，与 `/me` 私有 view 解耦更清晰。

- [ ] **Step 2: 在 return dict 里加 `"personal_services"` key**

  原本的 return 结构（约 432-499 行）末尾在 `"sold_flea_items": [...]` 之后，加：

  ```python
          "personal_services": [_serialize_personal_service(s) for s in personal_service_rows],
  ```

- [ ] **Step 3: 运行测试，确认通过**

  ```bash
  cd backend
  pytest tests/test_profile_routes_personal_services.py -v
  ```

  Expected: 两个测试都通过。

- [ ] **Step 4: 跑整个 profile 测试套件，确保没破坏其他 endpoint**

  ```bash
  pytest tests/ -k "profile" -v
  ```

  Expected: 全部 PASS。

- [ ] **Step 5: 清缓存验证**

  `@cache_response(ttl=300, key_prefix="user_profile")` 装饰器加新字段后老缓存仍按旧 schema 命中。本地开发环境触发刷新：

  ```bash
  # 重启后端服务即清进程内缓存。如果用 Redis 缓存，flush 对应 key:
  redis-cli --scan --pattern "user_profile:*" | xargs -r redis-cli del
  ```

  生产部署后 5 分钟内会自然过期，不需要手动操作。在 plan 里记一下，避免实施时被「字段没出现」这个表象误导。

- [ ] **Step 6: Commit**

  ```bash
  git add backend/app/routes/profile_routes.py
  git commit -m "feat(profile): include personal_services in /profile/{user_id} response"
  ```

---

## Task 3: 后端 — 推 main 触发 staging 部署 + 自查

Per memory：`推 main 后用 linktest.up.railway.app 验证部署；api.link2ur.com 是 prod，不会自动跟进`。

- [ ] **Step 1: Push**

  ```bash
  git push
  ```

- [ ] **Step 2: 等 Railway 部署完（通常 1-2 分钟），手动验证**

  ```bash
  curl -s https://linktest.up.railway.app/profile/00000099 | python -m json.tool | head -50
  ```

  Expected: JSON 中含 `"personal_services": [...]` key。如果存量数据中找不到合适 user，用一个真实有服务的 user_id 替换。

  如果返回里**没有** `personal_services`：
  - 检查 Railway log 是否有 import error（`ImportError: cannot import name 'TaskExpertService'`）
  - 老缓存可能仍在 —— 等 5 分钟或 flush Redis

---

## Task 4: Flutter — 写失败测试（UserProfileDetail.fromJson 应解析 personal_services）

**Files:**
- Create: `link2ur/test/data/models/user_profile_personal_services_test.dart`

- [ ] **Step 1: 写测试**

  ```dart
  // link2ur/test/data/models/user_profile_personal_services_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:link2ur/data/models/user.dart';

  void main() {
    group('UserProfileDetail.personalServices', () {
      Map<String, dynamic> _baseJson() => {
        'user': {
          'id': '00000099',
          'name': '周哲',
          'avatar': null,
          'created_at': '2025-01-01T00:00:00Z',
          'is_verified': false,
          'user_level': 'vip',
          'avg_rating': 4.9,
          'task_count': 0,
          'completed_task_count': 18,
          'is_expert': false,
          'is_student_verified': true,
          'profile_views': 0,
          'bio': '测试',
          'residence_city': 'London',
          'followers_count': 0,
          'following_count': 0,
          'is_following': false,
          'displayed_badge': null,
        },
        'stats': {},
        'recent_tasks': [],
        'reviews': [],
        'recent_forum_posts': [],
        'sold_flea_items': [],
      };

      test('parses non-empty personal_services array', () {
        final json = _baseJson();
        json['personal_services'] = [
          {
            'id': 1,
            'service_name': '家教 · 小学数学',
            'service_name_en': null,
            'service_name_zh': null,
            'description': 'UCL 在读',
            'category': 'tutoring',
            'base_price': 15.0,
            'currency': 'GBP',
            'pricing_type': 'fixed',
            'location_type': 'both',
            'location': 'London',
            'images': [],
            'status': 'active',
          },
        ];

        final detail = UserProfileDetail.fromJson(json);
        expect(detail.personalServices, hasLength(1));
        final s = detail.personalServices.first;
        expect(s.id, 1);
        expect(s.serviceName, '家教 · 小学数学');
        expect(s.category, 'tutoring');
        expect(s.basePrice, 15.0);
        expect(s.currency, 'GBP');
        expect(s.pricingType, 'fixed');
      });

      test('defaults to empty list when key absent', () {
        final detail = UserProfileDetail.fromJson(_baseJson());
        expect(detail.personalServices, isEmpty);
      });

      test('defaults to empty list when key is null', () {
        final json = _baseJson();
        json['personal_services'] = null;
        final detail = UserProfileDetail.fromJson(json);
        expect(detail.personalServices, isEmpty);
      });
    });
  }
  ```

- [ ] **Step 2: 运行测试，确认失败**

  ```powershell
  $env:PATH = "F:\flutter\bin;" + $env:PATH
  $env:PUB_CACHE = "F:\DevCache\.pub-cache"
  cd link2ur
  flutter test test/data/models/user_profile_personal_services_test.dart
  ```

  Expected: 编译失败 —— `personalServices` 字段未定义。

- [ ] **Step 3: Commit**

  ```bash
  git add link2ur/test/data/models/user_profile_personal_services_test.dart
  git commit -m "test(profile): assert UserProfileDetail parses personal_services"
  ```

---

## Task 5: Flutter — 加 UserProfilePersonalService 模型 + 扩展 UserProfileDetail

**Files:**
- Modify: `link2ur/lib/data/models/user.dart:282-351`（UserProfileDetail 类） + 在文件末尾加新数据类

- [ ] **Step 1: 在 user.dart 末尾加 UserProfilePersonalService 类**

  打开 `link2ur/lib/data/models/user.dart`，在文件最末尾（`UserProfileFleaItem` 类之后）追加：

  ```dart
  /// 个人服务（task_expert_services 表 service_type='personal' 行的公开视图）。
  /// 仅用于他人主页展示，不含 owner 私有字段。
  class UserProfilePersonalService {
    const UserProfilePersonalService({
      required this.id,
      required this.serviceName,
      this.serviceNameEn,
      this.serviceNameZh,
      this.description,
      this.descriptionEn,
      this.descriptionZh,
      this.category,
      required this.basePrice,
      this.currency = 'GBP',
      this.pricingType = 'fixed',
      this.locationType = 'online',
      this.location,
      this.images = const [],
      this.viewCount = 0,
    });

    final int id;
    final String serviceName;
    final String? serviceNameEn;
    final String? serviceNameZh;
    final String? description;
    final String? descriptionEn;
    final String? descriptionZh;
    final String? category;
    final double basePrice;
    final String currency;
    final String pricingType; // 'fixed' | 'negotiable'
    final String locationType; // 'online' | 'in_person' | 'both'
    final String? location;
    final List<String> images;
    final int viewCount;

    factory UserProfilePersonalService.fromJson(Map<String, dynamic> json) {
      return UserProfilePersonalService(
        id: json['id'] as int,
        serviceName: json['service_name'] as String? ?? '',
        serviceNameEn: json['service_name_en'] as String?,
        serviceNameZh: json['service_name_zh'] as String?,
        description: json['description'] as String?,
        descriptionEn: json['description_en'] as String?,
        descriptionZh: json['description_zh'] as String?,
        category: json['category'] as String?,
        basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'GBP',
        pricingType: json['pricing_type'] as String? ?? 'fixed',
        locationType: json['location_type'] as String? ?? 'online',
        location: json['location'] as String?,
        images: ((json['images'] as List<dynamic>?) ?? [])
            .whereType<String>()
            .toList(),
        viewCount: json['view_count'] as int? ?? 0,
      );
    }

    /// 按当前 locale 返回 service_name 的本地化版本。
    String displayName(Locale locale) {
      final lang = locale.languageCode;
      if (lang == 'en' && (serviceNameEn?.isNotEmpty ?? false)) {
        return serviceNameEn!;
      }
      if (lang == 'zh' && (serviceNameZh?.isNotEmpty ?? false)) {
        return serviceNameZh!;
      }
      return serviceName;
    }
  }
  ```

  > 注意：`Locale` 来自 `dart:ui`，user.dart 顶部如未 import 需要加 `import 'dart:ui' show Locale;`（先看现有 imports，`flutter/material.dart` 已经间接 export Locale，多数情况下不用单独加）。

- [ ] **Step 2: 扩展 UserProfileDetail 加 personalServices 字段**

  改 `UserProfileDetail` 类（约 282-351 行）：

  ```dart
  class UserProfileDetail {
    const UserProfileDetail({
      required this.user,
      required this.stats,
      this.recentTasks = const [],
      this.reviews = const [],
      this.recentForumPosts = const [],
      this.soldFleaItems = const [],
      this.personalServices = const [],   // ← 新增
      this.isFollowing = false,
      this.followersCount = 0,
      this.followingCount = 0,
    });

    final User user;
    final UserProfileStats stats;
    final List<UserProfileTask> recentTasks;
    final List<UserProfileReview> reviews;
    final List<UserProfileForumPost> recentForumPosts;
    final List<UserProfileFleaItem> soldFleaItems;
    final List<UserProfilePersonalService> personalServices;   // ← 新增
    final bool isFollowing;
    final int followersCount;
    final int followingCount;

    factory UserProfileDetail.fromJson(Map<String, dynamic> json) {
      final userJson = json['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        throw FormatException(
          'Profile response missing user. Keys: ${json.keys.toList()}',
        );
      }
      final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
      final recentTasksRaw =
          json['recent_tasks'] as List<dynamic>? ?? [];
      final reviewsRaw = json['reviews'] as List<dynamic>? ?? [];
      final forumPostsRaw =
          json['recent_forum_posts'] as List<dynamic>? ?? [];
      final fleaItemsRaw =
          json['sold_flea_items'] as List<dynamic>? ?? [];
      final personalServicesRaw =                              // ← 新增
          json['personal_services'] as List<dynamic>? ?? [];

      return UserProfileDetail(
        user: User.fromJson(userJson),
        stats: UserProfileStats.fromJson(
          Map<String, dynamic>.from(statsJson),
        ),
        isFollowing: userJson['is_following'] == true,
        followersCount: userJson['followers_count'] as int? ?? 0,
        followingCount: userJson['following_count'] as int? ?? 0,
        recentTasks: recentTasksRaw
            .map((e) => UserProfileTask.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        reviews: reviewsRaw
            .map((e) => UserProfileReview.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        recentForumPosts: forumPostsRaw
            .map((e) => UserProfileForumPost.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        soldFleaItems: fleaItemsRaw
            .map((e) => UserProfileFleaItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        personalServices: personalServicesRaw                  // ← 新增
            .map((e) => UserProfilePersonalService.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
      );
    }
  }
  ```

- [ ] **Step 3: 运行测试，确认通过**

  ```powershell
  cd link2ur
  flutter test test/data/models/user_profile_personal_services_test.dart
  ```

  Expected: 3 tests PASS.

- [ ] **Step 4: 把 UserProfilePersonalService export 到 user_profile_view 引用的位置**

  打开 `link2ur/lib/features/profile/views/user_profile_view.dart`，找到顶部 `import '../../../data/models/user.dart' show ...` 那行（约第 25 行），加 `UserProfilePersonalService`：

  ```dart
  import '../../../data/models/user.dart' show
      User,
      UserProfileDetail,
      UserProfileReview,
      UserProfileForumPost,
      UserProfileFleaItem,
      UserProfilePersonalService;   // ← 新增
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add link2ur/lib/data/models/user.dart link2ur/lib/features/profile/views/user_profile_view.dart
  git commit -m "feat(profile): add UserProfilePersonalService model + parse field"
  ```

---

## Task 6: Flutter — 加 l10n keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: 加英文 keys**

  `link2ur/lib/l10n/app_en.arb` 在合适位置（搜 `profileSoldItems` 之后）追加：

  ```json
  "profilePersonalServices": "Personal Services",
  "profilePersonalServicesCount": "{count, plural, =1{·1 item} other{·{count} items}}",
  "@profilePersonalServicesCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "profileServicePriceFrom": "from",
  "profileServiceNegotiable": "Negotiable",
  ```

- [ ] **Step 2: 加简体中文 keys**

  `link2ur/lib/l10n/app_zh.arb`：

  ```json
  "profilePersonalServices": "个人服务",
  "profilePersonalServicesCount": "· {count} 项",
  "@profilePersonalServicesCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "profileServicePriceFrom": "起",
  "profileServiceNegotiable": "议价",
  ```

- [ ] **Step 3: 加繁体中文 keys**

  `link2ur/lib/l10n/app_zh_Hant.arb`：

  ```json
  "profilePersonalServices": "個人服務",
  "profilePersonalServicesCount": "· {count} 項",
  "@profilePersonalServicesCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "profileServicePriceFrom": "起",
  "profileServiceNegotiable": "議價",
  ```

- [ ] **Step 4: 重新生成 l10n**

  ```powershell
  cd link2ur
  flutter gen-l10n
  ```

  Expected: 无 error，`lib/l10n/app_localizations*.dart` 自动更新。

- [ ] **Step 5: 跑 analyzer 检查 ARB JSON 语法**

  ```powershell
  flutter analyze lib/l10n/
  ```

  Expected: No issues found.

- [ ] **Step 6: Commit**

  ```bash
  git add link2ur/lib/l10n/
  git commit -m "i18n(profile): add personal services section keys (en/zh/zh_Hant)"
  ```

---

## Task 7: Flutter — 写失败 widget 测试（独立 PersonalServicesSection widget）

> **设计决策**：把 section 做成独立的 public widget `PersonalServicesSection`，而不是 `UserProfileView` 的私有方法。这样可以脱离 BLoC 直接测，避开 `UserProfileView` 内部 `BlocProvider(create: ...)` 创建独立 bloc 导致 mock 不生效的问题。空列表的隐藏判断也下放到 widget 自身，view 层引用更干净。

**Files:**
- Create: `link2ur/test/features/profile/personal_services_section_test.dart`

- [ ] **Step 1: 写测试（针对一个待创建的 PersonalServicesSection widget）**

  ```dart
  // link2ur/test/features/profile/personal_services_section_test.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  import 'package:link2ur/data/models/user.dart';
  import 'package:link2ur/features/profile/views/widgets/personal_services_section.dart';
  import 'package:link2ur/l10n/app_localizations.dart';

  void main() {
    UserProfilePersonalService _svc(int id, String name, {String? cat, String pricingType = 'fixed', double price = 15.0}) =>
        UserProfilePersonalService(
          id: id,
          serviceName: name,
          basePrice: price,
          category: cat ?? 'tutoring',
          pricingType: pricingType,
        );

    Widget _harness(List<UserProfilePersonalService> services) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: PersonalServicesSection(services: services),
          ),
        );

    testWidgets('renders title and each service when non-empty', (tester) async {
      await tester.pumpWidget(_harness([
        _svc(1, '家教 · 小学数学'),
        _svc(2, '伦敦市内代取', cat: 'errand'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('个人服务'), findsOneWidget);
      expect(find.text('家教 · 小学数学'), findsOneWidget);
      expect(find.text('伦敦市内代取'), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink (no UI) when empty', (tester) async {
      await tester.pumpWidget(_harness(const []));
      await tester.pumpAndSettle();

      expect(find.text('个人服务'), findsNothing);
      // 整个 widget 折叠成 0 高度，不留空白卡
      final renderBox = tester.renderObject<RenderBox>(
        find.byType(PersonalServicesSection),
      );
      expect(renderBox.size.height, 0);
    });

    testWidgets('shows "议价" label for negotiable pricing_type', (tester) async {
      await tester.pumpWidget(_harness([
        _svc(1, '私人教练', pricingType: 'negotiable', price: 0.0),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('议价'), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: 运行测试，确认失败**

  ```powershell
  cd link2ur
  flutter test test/features/profile/personal_services_section_test.dart
  ```

  Expected: 编译失败 —— `personal_services_section.dart` 不存在。

- [ ] **Step 3: Commit**

  ```bash
  git add link2ur/test/features/profile/personal_services_section_test.dart
  git commit -m "test(profile): assert PersonalServicesSection renders, hides on empty, handles negotiable"
  ```
---

## Task 8: Flutter — 创建 PersonalServicesSection widget + 接入 UserProfileView

**Files:**
- Create: `link2ur/lib/features/profile/views/widgets/personal_services_section.dart`
- Modify: `link2ur/lib/features/profile/views/user_profile_view.dart`

- [ ] **Step 1: 创建 PersonalServicesSection widget 文件**

  ```dart
  // link2ur/lib/features/profile/views/widgets/personal_services_section.dart
  import 'package:flutter/material.dart';

  import '../../../../core/design/app_colors.dart';
  import '../../../../core/design/app_radius.dart';
  import '../../../../core/design/app_spacing.dart';
  import '../../../../core/design/app_typography.dart';
  import '../../../../core/utils/helpers.dart';
  import '../../../../core/utils/l10n_extension.dart';
  import '../../../../core/widgets/async_image_view.dart';
  import '../../../../data/models/user.dart' show UserProfilePersonalService;

  /// 普通用户主页的「个人服务」section。
  /// 服务列表为空时整体折叠为 SizedBox.shrink，不留空白卡。
  class PersonalServicesSection extends StatelessWidget {
    const PersonalServicesSection({super.key, required this.services});

    final List<UserProfilePersonalService> services;

    @override
    Widget build(BuildContext context) {
      if (services.isEmpty) return const SizedBox.shrink();

      final l10n = context.l10n;
      final locale = Localizations.localeOf(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.profilePersonalServices,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text(l10n.profilePersonalServicesCount(services.length),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: AppSpacing.md),
            ...services.map((s) => Padding(
                  key: ValueKey('personal_service_${s.id}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PersonalServiceCard(service: s, locale: locale, isDark: isDark),
                )),
          ],
        ),
      );
    }
  }

  class _PersonalServiceCard extends StatelessWidget {
    const _PersonalServiceCard({
      required this.service,
      required this.locale,
      required this.isDark,
    });

    final UserProfilePersonalService service;
    final Locale locale;
    final bool isDark;

    @override
    Widget build(BuildContext context) {
      final priceText = _priceText(context);

      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(service.displayName(locale))),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allMedium,
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                gradient: _categoryGradient(service.category),
              ),
              alignment: Alignment.center,
              child: service.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      child: AsyncImageView(
                        imageUrl: Helpers.getThumbnailUrl(service.images.first),
                        fallbackUrl: Helpers.getImageUrl(service.images.first),
                        width: 56, height: 56,
                      ),
                    )
                  : Icon(_categoryIcon(service.category), color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.displayName(locale),
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((service.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(service.description!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(priceText,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary,
                )),
          ]),
        ),
      );
    }

    String _priceText(BuildContext context) {
      final l10n = context.l10n;
      if (service.pricingType == 'negotiable') return l10n.profileServiceNegotiable;
      final symbol = Helpers.currencySymbolFor(service.currency);
      return '$symbol${service.basePrice.toStringAsFixed(0)} ${l10n.profileServicePriceFrom}';
    }

    IconData _categoryIcon(String? category) {
      switch (category) {
        case 'tutoring': return Icons.school_outlined;
        case 'errand':
        case 'pickup_dropoff': return Icons.delivery_dining_outlined;
        case 'photography': return Icons.camera_alt_outlined;
        case 'design': return Icons.palette_outlined;
        case 'translation': return Icons.translate_outlined;
        case 'programming': return Icons.code_outlined;
        case 'cleaning': return Icons.cleaning_services_outlined;
        case 'cooking': return Icons.restaurant_outlined;
        case 'pet_care': return Icons.pets_outlined;
        default: return Icons.work_outline;
      }
    }

    LinearGradient _categoryGradient(String? category) {
      switch (category) {
        case 'tutoring':
          return const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]);
        case 'errand':
        case 'pickup_dropoff':
          return const LinearGradient(colors: [Color(0xFFBFDBFE), Color(0xFF3B82F6)]);
        case 'photography':
          return const LinearGradient(colors: [Color(0xFFFBCFE8), Color(0xFFEC4899)]);
        case 'design':
          return const LinearGradient(colors: [Color(0xFFDDD6FE), Color(0xFF7C3AED)]);
        default:
          return const LinearGradient(colors: [Color(0xFFE0E7FF), Color(0xFF6366F1)]);
      }
    }
  }
  ```

- [ ] **Step 2: 在 user_profile_view.dart 引用并接入**

  顶部 import 区加：

  ```dart
  import 'widgets/personal_services_section.dart';
  ```

  在 `Column` 的 children 中（合作记录 BlocBuilder 之后、评价 `if` 之前）插入：

  ```dart
                                            PersonalServicesSection(
                                              services: state.publicProfileDetail?.personalServices ?? const [],
                                            ),
  ```

  注意：widget 内部已处理空列表，**不需要再包 `if (...isNotEmpty == true)`**。

- [ ] **Step 3: 跑 widget 测试**

  ```powershell
  cd link2ur
  flutter test test/features/profile/personal_services_section_test.dart
  ```

  Expected: 3 个测试通过。

- [ ] **Step 4: analyze**

  ```powershell
  flutter analyze lib/features/profile/views/widgets/personal_services_section.dart lib/features/profile/views/user_profile_view.dart
  ```

  Expected: No issues found.

- [ ] **Step 5: Commit**

  ```bash
  git add link2ur/lib/features/profile/views/widgets/personal_services_section.dart link2ur/lib/features/profile/views/user_profile_view.dart
  git commit -m "feat(profile): render PersonalServicesSection on public user profile"
  ```

---

## Task 9: 端到端冒烟（手机模拟器或 web）

- [ ] **Step 1: 启动 web 模式**

  ```powershell
  cd link2ur
  flutter run -d web-server
  ```

  打开提示的 `http://localhost:xxxxx`。

- [ ] **Step 2: 登录 staging 账号，访问 /user/00000099（或任意发布过 personal service 的真实账号）**

  通过路由 `/profile/user/{id}` 进入他人主页。

- [ ] **Step 3: 验证清单**

  - [ ] 个人服务 section 在「合作记录」之后、「评价」之前出现
  - [ ] 服务标题、描述、价格按 locale 显示正确（切语言验证 zh / en / zh_Hant）
  - [ ] `pricing_type='negotiable'` 的服务显示「议价」/ "Negotiable"
  - [ ] 没发布过 personal service 的用户主页该 section **不出现**（不是空白卡）
  - [ ] 暗黑模式下卡片背景颜色正确

- [ ] **Step 4: 修复 / commit 任何视觉小问题**

  如果发现 spacing / 颜色不对，单独 commit fix。

---

## Task 10: 推 main 部署 + 验证

- [ ] **Step 1: 确认 build 通过**

  ```powershell
  flutter build apk --debug
  ```

  Expected: BUILD SUCCESSFUL。

- [ ] **Step 2: Push**

  ```bash
  git push
  ```

- [ ] **Step 3: 等 Railway 部署完后访问 staging**

  ```bash
  curl -s https://linktest.up.railway.app/profile/<known-user-id> | python -m json.tool | grep -A 3 personal_services
  ```

- [ ] **Step 4: 用 Flutter app 连 staging 验证一遍真实用户主页**

  改 `AppConfig` 临时指向 linktest，或在 dev mode 直接访问。

---

## 完成判定

全部 task 走完后，下列条件应同时成立：

- ✅ `pytest backend/tests/test_profile_routes_personal_services.py` 全绿
- ✅ `flutter test` 全绿（含两份新测试）
- ✅ `flutter analyze` 无 issue
- ✅ Staging `/profile/{user_id}` 返回 `personal_services` 数组
- ✅ 在 Flutter app 中，发布过 personal service 的用户主页能看到该 section；未发布的用户主页**不留空白**
- ✅ 三种语言（en/zh/zh_Hant）section 标题和价格文案正确

---

## 风险点 / 注意事项

1. **Profile API 缓存**：`@cache_response(ttl=300, key_prefix="user_profile")` 在加新字段后会让老缓存继续返回旧 schema。生产部署后等 5 分钟自然过期；本地需手动重启或 flush Redis。
2. **Pydantic v2 + async lazy-load 陷阱**（per memory）：本 plan 没有引入 Pydantic 嵌套 schema，profile_routes 的 endpoint 仍返回 plain dict，无此风险。
3. **达人主页**：达人主页（`expert_team_view`）应展示 `service_type='expert'` 的服务，**不应**因为这次改动错误展示 personal services。本 plan 不动达人页代码，但实施时可顺手 grep 一下确认 `expert_routes.py` / `expert_service_routes.py` 仍然 filter `service_type='expert'`。
4. **service_radius_km / latitude / longitude**：本 plan 故意不展示这些字段（公开页面没有距离感知场景）。如果以后做「附近服务」discovery，到时候再加。
5. **`view_count` 自增**：本 plan 只读 `view_count`，不在 profile 接口里递增（profile API 已经在自增 `profile_views` 是用户的，service 的 view 应当在「服务详情页」视图里递增，不在这里）。
