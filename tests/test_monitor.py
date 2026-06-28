"""Small unit test for monitor check_rules_once behavior."""
from __future__ import annotations

from aksu_stock.services.monitor import check_rules_once


def test_check_rules_with_mock_current():
    cfg = {
        "positions": [
            {"symbol": "TEST", "buy_price": 100.0, "mock_current": 80.0, "alert_cost_pct": -10},
            {"symbol": "TEST2", "buy_price": 10.0, "mock_current": 11.0, "alert_cost_pct": -20},
        ]
    }
    res = check_rules_once(cfg)
    assert isinstance(res, dict)
    assert "alerts" in res
    # first position: 80 vs 100 = -20% -> should trigger (threshold -10)
    assert any(a.get("symbol") == "TEST" for a in res["alerts"])
