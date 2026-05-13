"""Tests for helper_recommendation module."""

import pytest


def test_normalize_city_lowercase():
    """City names are lowercased and stripped."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("London") == "london"
    assert normalize_city("  London  ") == "london"


def test_normalize_city_chinese_to_english():
    """Chinese city names are mapped to English."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("伦敦") == "london"
    assert normalize_city("曼城") == "manchester"
    assert normalize_city("爱丁堡") == "edinburgh"


def test_normalize_city_unknown_returns_none():
    """Unknown city returns None for downstream 'unknown city' handling."""
    from app.services.helper_recommendation import normalize_city
    assert normalize_city("") is None
    assert normalize_city(None) is None
    assert normalize_city("Atlantis") is None  # 不在白名单
