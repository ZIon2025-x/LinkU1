"""Migration 210 单元测试 — 验证字段回填策略、幂等性、orphan EXCEPTION 行为。

测试假设:
- DATABASE_URL / TEST_DATABASE_URL 指向一个已跑到 migration 209 的真实 PG 实例
- CI 里由 service 提供；本地开发者需自行运行 PG
- SQLite fallback 跳过（DO block + JSONB cast 不兼容）

使用 conftest.py 的 db fixture (rollback-based isolation)。每个 test 自
插入 legacy 数据 → 直接执行 210 SQL → 断言 → 由 fixture rollback。
"""
from decimal import Decimal
from pathlib import Path

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import models
from app.models_expert import Expert, ExpertMember

MIGRATION_210_PATH = (
    Path(__file__).resolve().parents[2] / "migrations" / "210_sync_expert_fields_from_legacy.sql"
)


@pytest.fixture(scope="session", autouse=True)
def _ensure_expert_migration_map(_tables):
    """CI 的 conftest 只跑 Base.metadata.create_all(),不会创建 migration 159
    里的 _expert_id_migration_map 辅助表(它没有对应的 ORM 模型)。此 fixture
    在测试 session 启动时用独立连接建表并 commit,使后续测试的 INSERT 可见。"""
    if _tables.dialect.name != "postgresql":
        return
    with _tables.begin() as conn:
        conn.execute(
            text(
                "CREATE TABLE IF NOT EXISTS _expert_id_migration_map ("
                "  old_id VARCHAR(8) PRIMARY KEY,"
                "  new_id VARCHAR(8) NOT NULL UNIQUE"
                ")"
            )
        )


def _pg_only(db: Session):
    """SQLite 不支持 DO block + JSONB cast;skip 该测试。"""
    dialect = db.bind.dialect.name
    if dialect != "postgresql":
        pytest.skip(f"migration 210 test requires PostgreSQL, got {dialect}")


def _run_210(db: Session) -> None:
    """把 SQL 文件分 statement 执行 (对齐 execute_sql_file 行为)。

    Isolation note: 该 raw cursor 从 db.connection().connection 取得,
    即 conftest 的 fixture connection 的底层 DBAPI 连接. fixture 的
    connection.begin() 在同一连接上开 transaction, 所以 raw cursor 的
    所有写入都在该 transaction 内; teardown 的 transaction.rollback()
    会一并回滚. 测试套件反复运行无数据残留, 此隔离方案经过验证。
    """
    sql = MIGRATION_210_PATH.read_text(encoding="utf-8")
    # execute_sql_file 用 split_sql_statements,但 DO 块是一个整体;简化用 execute 整个文件
    # PG 的 psycopg2 cursor 对多 statement 单调用会按 \n; 拆分执行
    raw = db.connection().connection
    with raw.cursor() as cur:
        cur.execute(sql)


_ADMIN_ID = "T0001"  # Reused across tests (same rollback scope)


def _ensure_admin(db: Session) -> None:
    """Ensure a test admin user exists (needed for featured_task_experts.created_by FK)."""
    existing = db.execute(
        text("SELECT id FROM admin_users WHERE id = :id"),
        {"id": _ADMIN_ID},
    ).first()
    if existing is None:
        db.execute(
            text(
                "INSERT INTO admin_users (id, name, username, email, hashed_password) "
                "VALUES (:id, 'Test Admin', 'testadmin', 'testadmin@test.local', 'x')"
                " ON CONFLICT DO NOTHING"
            ),
            {"id": _ADMIN_ID},
        )
        db.flush()


def _make_user(db: Session, user_id: str) -> models.User:
    u = models.User(id=user_id, name=f"U{user_id}", email=f"{user_id}@test.local", hashed_password="x")
    db.add(u)
    db.flush()
    return u


def _make_legacy_te(db: Session, user_id: str, **kwargs) -> models.TaskExpert:
    te = models.TaskExpert(
        id=user_id,
        expert_name=kwargs.get("expert_name", f"TE {user_id}"),
        bio=kwargs.get("bio"),
        avatar=kwargs.get("avatar"),
        status=kwargs.get("status", "active"),
        rating=kwargs.get("rating", Decimal("0.00")),
        total_services=kwargs.get("total_services", 0),
        completed_tasks=kwargs.get("completed_tasks", 0),
        is_official=kwargs.get("is_official", False),
        official_badge=kwargs.get("official_badge"),
    )
    db.add(te)
    db.flush()
    return te


def _make_legacy_fte(db: Session, user_id: str, **kwargs) -> None:
    """Insert FeaturedTaskExpert row for tests.

    NOTE: FTE.id FK → users.id で user_id と同値にする必要がある (生産スキーマ制約).
    テスト内では user_id == fte.id と理解した上で使用すること。
    """
    _ensure_admin(db)
    db.execute(
        text(
            "INSERT INTO featured_task_experts "
            "(id, user_id, name, bio_en, avg_rating, completed_tasks, total_tasks, "
            "completion_rate, success_rate, expertise_areas, expertise_areas_en, "
            "response_time, category, location, is_verified, is_featured, display_order, created_by) "
            "VALUES (:id, :uid, :name, :bio_en, :avg_rating, :completed_tasks, :total_tasks, "
            ":completion_rate, :success_rate, :expertise_areas, :expertise_areas_en, "
            ":response_time, :category, :location, :is_verified, :is_featured, :display_order, :created_by)"
        ),
        {
            "id": user_id,  # FTE.id FK → users.id; 生产表 id == user_id
            "uid": user_id,
            "name": kwargs.get("name", f"FTE {user_id}"),
            "bio_en": kwargs.get("bio_en"),
            "avg_rating": kwargs.get("avg_rating", 0.0),
            "completed_tasks": kwargs.get("completed_tasks", 0),
            "total_tasks": kwargs.get("total_tasks", 0),
            "completion_rate": kwargs.get("completion_rate", 0.0),
            "success_rate": kwargs.get("success_rate", 0.0),
            "expertise_areas": kwargs.get("expertise_areas"),
            "expertise_areas_en": kwargs.get("expertise_areas_en"),
            "response_time": kwargs.get("response_time"),
            "category": kwargs.get("category"),
            "location": kwargs.get("location"),
            "is_verified": kwargs.get("is_verified", 0),
            "is_featured": kwargs.get("is_featured", 1),
            "display_order": kwargs.get("display_order", 0),
            "created_by": kwargs.get("created_by", _ADMIN_ID),
        },
    )
    db.flush()


def _make_expert_via_map(db: Session, user_id: str, new_id: str, **kwargs) -> Expert:
    """创建 Expert + ExpertMember(owner) + 写映射,模拟 migration 159/185 的产物。"""
    expert = Expert(
        id=new_id,
        name=kwargs.get("name", f"Team for {user_id}"),
        status="active",
        rating=kwargs.get("rating", Decimal("0.00")),
        total_services=kwargs.get("total_services", 0),
        completed_tasks=kwargs.get("completed_tasks", 0),
        completion_rate=kwargs.get("completion_rate", 0.0),
        # success_rate 列由 210 的 ALTER 添加; Expert model 已含该字段 default 0.0
    )
    db.add(expert)
    db.add(ExpertMember(expert_id=new_id, user_id=user_id, role="owner", status="active"))
    db.execute(
        text(
            "INSERT INTO _expert_id_migration_map (old_id, new_id) "
            "VALUES (:o, :n) ON CONFLICT DO NOTHING"
        ),
        {"o": user_id, "n": new_id},
    )
    db.flush()
    return expert


def test_210_syncs_stats_from_task_experts(db: Session):
    """TE 的 rating / total_services / completed_tasks 应覆盖到 Expert"""
    _pg_only(db)
    _make_user(db, "20000001")
    _make_legacy_te(
        db,
        "20000001",
        rating=Decimal("4.50"),
        total_services=10,
        completed_tasks=15,
    )
    _make_expert_via_map(db, "20000001", "E0000001")
    _run_210(db)

    expert = db.get(Expert, "E0000001")
    db.refresh(expert)
    assert expert.rating == Decimal("4.50")
    assert expert.total_services == 10
    assert expert.completed_tasks == 15


def test_210_syncs_completion_rate_from_fte(db: Session):
    """completion_rate 权威源是 FTE (TE 无此字段,模型未定义)"""
    _pg_only(db)
    _make_user(db, "20000002")
    _make_legacy_te(db, "20000002")
    _make_legacy_fte(db, "20000002", completion_rate=87.5)
    _make_expert_via_map(db, "20000002", "E0000002", completion_rate=0.0)
    _run_210(db)

    expert = db.get(Expert, "E0000002")
    db.refresh(expert)
    assert expert.completion_rate == pytest.approx(87.5)


def test_210_syncs_success_rate(db: Session):
    """success_rate 列由 210 的 ALTER 添加,然后从 FTE 回填"""
    _pg_only(db)
    _make_user(db, "20000003")
    _make_legacy_te(db, "20000003")
    _make_legacy_fte(db, "20000003", success_rate=92.3)
    _make_expert_via_map(db, "20000003", "E0000003")
    _run_210(db)

    row = db.execute(
        text("SELECT success_rate FROM experts WHERE id = :id"),
        {"id": "E0000003"},
    ).first()
    assert row is not None
    assert row[0] == pytest.approx(92.3)


def test_210_syncs_featured_experts_v2(db: Session):
    """Step 5: FV2.category / is_featured / display_order 从 FTE 回填 (COALESCE)"""
    _pg_only(db)
    _make_user(db, "20000009")
    _make_legacy_te(db, "20000009")
    _make_legacy_fte(
        db, "20000009",
        category="programming",
        is_featured=1,
        display_order=10,
    )
    _make_expert_via_map(db, "20000009", "E0000009")

    # 插入一条 fv2 空 category / 默认 is_featured=False / display_order=0
    _ensure_admin(db)
    db.execute(
        text(
            "INSERT INTO featured_experts_v2 (expert_id, is_featured, display_order, created_by) "
            "VALUES (:eid, false, 0, (SELECT id FROM admin_users LIMIT 1))"
        ),
        {"eid": "E0000009"},
    )
    db.flush()

    _run_210(db)

    row = db.execute(
        text(
            "SELECT category, is_featured, display_order FROM featured_experts_v2 "
            "WHERE expert_id = :eid"
        ),
        {"eid": "E0000009"},
    ).first()
    assert row is not None
    assert row[0] == "programming"  # category 从 FTE 回填
    assert row[1] is True            # is_featured 从 FTE.is_featured=1 转 True
    assert row[2] == 10              # display_order 从 FTE 回填


def test_210_backfills_bio_en_for_null_only(db: Session):
    """COALESCE 策略: Expert.bio_en 为空时从 FTE 取;非空时保留"""
    _pg_only(db)
    _make_user(db, "20000004")
    _make_legacy_te(db, "20000004")
    _make_legacy_fte(db, "20000004", bio_en="FTE english bio")
    expert = _make_expert_via_map(db, "20000004", "E0000004")
    expert.bio_en = None
    db.flush()

    _make_user(db, "20000005")
    _make_legacy_te(db, "20000005")
    _make_legacy_fte(db, "20000005", bio_en="Should not overwrite")
    expert_existing = _make_expert_via_map(db, "20000005", "E0000005")
    expert_existing.bio_en = "Existing bio should stay"
    db.flush()

    _run_210(db)

    db.refresh(expert)
    db.refresh(expert_existing)
    assert expert.bio_en == "FTE english bio"
    assert expert_existing.bio_en == "Existing bio should stay"


def test_210_preserves_newer_expert_name(db: Session):
    """Expert.updated_at 更新过 (即 admin 改过 name) → TE 的 expert_name 不覆盖"""
    _pg_only(db)
    _make_user(db, "20000006")
    te = _make_legacy_te(db, "20000006", expert_name="OLD NAME")
    # 手动把 TE 的 updated_at 设为过去 (避免与 Expert.updated_at 同秒)
    db.execute(
        text("UPDATE task_experts SET updated_at = NOW() - INTERVAL '1 day' WHERE id = :id"),
        {"id": "20000006"},
    )
    expert = _make_expert_via_map(db, "20000006", "E0000006", name="NEW NAME")
    # 显式把 Expert.updated_at 设为未来 (确保 te.updated_at < e.updated_at)
    db.execute(
        text("UPDATE experts SET updated_at = NOW() + INTERVAL '1 day' WHERE id = :id"),
        {"id": "E0000006"},
    )
    db.flush()
    _run_210(db)
    db.refresh(expert)
    assert expert.name == "NEW NAME"


def test_210_idempotent(db: Session):
    """跑两次应无副作用"""
    _pg_only(db)
    _make_user(db, "20000007")
    _make_legacy_te(db, "20000007", rating=Decimal("3.25"), completed_tasks=5)
    _make_expert_via_map(db, "20000007", "E0000007")

    _run_210(db)
    expert = db.get(Expert, "E0000007")
    db.refresh(expert)
    first_updated_at = expert.updated_at
    assert expert.rating == Decimal("3.25")

    # 手动刷新 updated_at 缓存再跑第二次
    db.flush()
    second_updated_at_before = expert.updated_at

    _run_210(db)
    db.refresh(expert)
    assert expert.rating == Decimal("3.25")
    # Step 1 使用 IS DISTINCT FROM 过滤,所以 rating 不变
    # NOTE: step 4 无 IS DISTINCT FROM 过滤, 会 bump updated_at (R13 已知折衷).
    # 因此这里只断言值不变, 不断言 updated_at — 和 spec §6.4/R13 一致。


def test_210_raises_on_orphan_task_experts(db: Session):
    """有 task_experts 行无映射 → DO 块 RAISE EXCEPTION 回滚"""
    _pg_only(db)
    _make_user(db, "20000008")
    _make_legacy_te(db, "20000008")
    # 不创建映射

    # execute 在 psycopg2 层会抛异常
    import psycopg2
    with pytest.raises(Exception) as exc_info:
        _run_210(db)
    # 必须包含 orphan 字样 (避免任何 DB 异常都通过)
    assert "orphan task_experts" in str(exc_info.value).lower()
    # 异常后 transaction 处于 aborted 状态, 回滚到保持 fixture 健康
    db.rollback()
