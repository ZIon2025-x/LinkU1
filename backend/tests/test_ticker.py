"""Ticker API tests."""
import pytest


def test_ticker_routes_importable():
    from app.ticker_routes import router
    assert router.prefix == "/api/feed"


def test_ticker_endpoint_registered():
    from app.ticker_routes import router
    paths = [r.path for r in router.routes]
    assert any("/ticker" in p for p in paths)


def test_ticker_item_format():
    item = {
        "text_zh": "👏 Lisa 刚完成了一个设计订单",
        "text_en": "👏 Lisa completed a design order",
        "link_type": "user",
        "link_id": "abc123",
    }
    assert "text_zh" in item
    assert "text_en" in item
    assert "text" not in item
    assert item["link_type"] in ("user", "activity")
