"""大学匹配器 — open-by-suffix 模式 (Lazy DB + seed JSON)。

不再需要 Aho-Corasick 或内存 university_map。
真实匹配请直接调用模块级 `match_university_by_email(email, db)`。
"""
import json
import logging
from pathlib import Path
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models

logger = logging.getLogger(__name__)


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
        # 1) email_domain race: 另一事务已 INSERT 同域名 → re-SELECT 拿赢家
        existing = db.query(models.University).filter(
            models.University.email_domain == registrable
        ).first()
        if existing:
            return existing
        # 2) name UNIQUE 冲突: seed 别名的 name 已被另一域名占用,用 "name (registrable)" 重试
        uni = models.University(
            email_domain=registrable,
            name=f"{name} ({registrable})",
            name_cn=name_cn,
            domain_pattern=f"@*.{registrable}",
            is_active=True,
        )
        db.add(uni)
        try:
            db.commit()
            db.refresh(uni)
        except IntegrityError:
            # 极端 case: disambiguated name 也冲突 → 放弃
            db.rollback()
            return None
    return uni
