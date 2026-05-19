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
        # Use a unique fictional domain to avoid conflicts with existing seed data
        db.add(models.University(
            name="Test University of Testland",
            name_cn="测试大学",
            email_domain="testland.ac.uk",
            domain_pattern="@*.testland.ac.uk",
            is_active=True,
        ))
        db.flush()

        uni = match_university_by_email("alice@student.testland.ac.uk", db)
        assert uni is not None
        assert uni.email_domain == "testland.ac.uk"
        assert uni.name == "Test University of Testland"

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

    def test_unique_name_collision_retries_with_disambiguator(self, db):
        """seed 别名 name 已被另一 email_domain 占用 → 重试用 disambiguated name 成功"""
        from app.university_matcher import match_university_by_email
        # 预先占用 seed 给 bcu.ac.uk 的 name (Birmingham City University)
        # 但分配给一个不同的 email_domain
        db.add(models.University(
            name="Birmingham City University",
            name_cn="伯明翰城市大学",
            email_domain="some-other-bcu-domain.ac.uk",
            domain_pattern="@*.some-other-bcu-domain.ac.uk",
            is_active=True,
        ))
        db.flush()

        # 现在 verify bcu.ac.uk 邮箱;seed 别名想用 "Birmingham City University" 名字
        # 但已被占,应该自动 fallback 到 disambiguated 名字
        uni = match_university_by_email("alice@mail.bcu.ac.uk", db)
        assert uni is not None
        assert uni.email_domain == "bcu.ac.uk"
        assert uni.name == "Birmingham City University (bcu.ac.uk)"
        assert uni.name_cn == "伯明翰城市大学"
