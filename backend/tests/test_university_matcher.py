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
