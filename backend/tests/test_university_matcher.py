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
