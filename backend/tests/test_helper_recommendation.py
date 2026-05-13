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


def test_geo_multiplier_offline_same_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", "london") == 1.3


def test_geo_multiplier_offline_cross_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", "manchester") == 0.4


def test_geo_multiplier_offline_unknown_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", "london", None) == 0.6


def test_geo_multiplier_both_same_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", "london") == 1.2


def test_geo_multiplier_both_cross_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", "manchester") == 0.7


def test_geo_multiplier_both_unknown_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("both", "london", None) == 0.9


def test_geo_multiplier_null_mode_treats_as_both():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier(None, "london", "london") == 1.2


def test_geo_multiplier_online_ignores_city():
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("online", "london", "manchester") == 1.0
    assert _geo_multiplier("online", "london", None) == 1.0


def test_geo_multiplier_user_city_none_with_known_candidate():
    """Caller has no city set; candidate has known city → 'cross' (penalized like cross-city mismatch)."""
    from app.services.helper_recommendation import _geo_multiplier
    assert _geo_multiplier("offline", None, "london") == 0.4
    assert _geo_multiplier("both", None, "manchester") == 0.7


def test_score_candidate_service_base():
    """service base 0.6, 无 boost, 无 geo 调整 (online)。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=None,
        completed_count=0,
        skills_overlap=0,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6)


def test_score_candidate_full_boost_clamps_to_1():
    """高 rating + 高 count + 满 skills overlap + 同城 offline → clamp 1.0。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=4.9,
        completed_count=20,
        skills_overlap=3,
        geo_multiplier=1.3,
    )
    assert s == pytest.approx(1.0)


def test_score_candidate_task_history_with_boosts():
    """task_history base 0.3 + rating 4.2 (+0.10) + count 5 (+0.05) + geo 1.2 = 0.54。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="task_history",
        avg_rating=4.2,
        completed_count=5,
        skills_overlap=0,
        geo_multiplier=1.2,
    )
    assert s == pytest.approx(0.54)


def test_score_candidate_low_rating_no_boost():
    """avg_rating < 3.0 不加 boost。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=2.5,
        completed_count=0,
        skills_overlap=0,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6)


def test_score_candidate_skills_overlap_capped_at_3():
    """skills_overlap 输入 5 也只算 3 个 (max +0.15)。"""
    from app.services.helper_recommendation import _score_candidate
    s = _score_candidate(
        source="service",
        avg_rating=None,
        completed_count=0,
        skills_overlap=5,
        geo_multiplier=1.0,
    )
    assert s == pytest.approx(0.6 + 0.15)


def test_match_reason_service_same_city_with_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=4.8,
        completed_count=0, task_type=None,
        city_state="same", city_display="伦敦",
    )
    assert r == "发布了陪逛服务,评分 4.8(伦敦)"


def test_match_reason_service_cross_city_with_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=4.5,
        completed_count=0, task_type=None,
        city_state="cross", city_display="曼城",
    )
    assert r == "发布了陪逛服务,评分 4.5(曼城,可线上协调)"


def test_match_reason_service_unknown_city_no_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="service", service_name="陪逛", avg_rating=None,
        completed_count=0, task_type=None,
        city_state="unknown", city_display=None,
    )
    assert r == "发布了陪逛服务"


def test_match_reason_task_history_same_city():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="task_history", service_name=None, avg_rating=4.6,
        completed_count=8, task_type="accompany",
        city_state="same", city_display="伦敦",
    )
    assert "完成过 8 个" in r
    assert "评分 4.6" in r
    assert "(伦敦)" in r


def test_match_reason_task_history_no_rating():
    from app.services.helper_recommendation import _build_match_reason
    r = _build_match_reason(
        source="task_history", service_name=None, avg_rating=None,
        completed_count=3, task_type="moving",
        city_state="unknown", city_display=None,
    )
    assert "完成过 3 个" in r
    assert "评分" not in r
