"""Monitor service (improved): use adapters for live prices and notify plugin for alerts.

Changes:
- Prefer live price from adapters in order: Tencent -> Sina -> Akshare, fall back to mock_current from config.
- When an alert trigger occurs, send a text notification via StubNotify (pluggable notify interface).
- Keep the simple PID-based start/stop/status CLI behavior.
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import threading
import time
from typing import Any, Dict, List, Optional

# import adapters (some may be None if not implemented)
from ..adapters import TencentAdapter, SinaAdapter, AkshareAdapter
from ..notify import StubNotify

PID_FILE = ".aksu_monitor.pid"


def load_config(path: str) -> Dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _extract_price_from_realtime(data: Dict[str, Any]) -> Optional[float]:
    if not data:
        return None
    # data is expected to be {"symbol": code, "latest": {...}} or adapter-specific
    latest = None
    if isinstance(data, dict):
        latest = data.get("latest") or data.get("raw") or data
    if not isinstance(latest, dict):
        return None
    # common candidate keys
    for k in ("最新价", "price", "current", "now", "close", "收盘", "最新"):  # some possibilities
        if k in latest:
            try:
                return float(latest.get(k) or 0)
            except Exception:
                pass
    # try common numeric fields
    for v in latest.values():
        try:
            return float(v)
        except Exception:
            continue
    return None


def _fetch_current_price(symbol: str) -> Optional[float]:
    """Try adapters in preferred order, return first available price or None."""
    # instantiate adapters (each adapter may be simple and cheap to create)
    price = None
    # Tencent
    try:
        t = TencentAdapter()
        r = t.fetch_realtime(symbol)
        if r.get("ok"):
            price = _extract_price_from_realtime(r.get("data"))
            if price:
                return price
    except Exception:
        pass
    # Sina
    try:
        s = SinaAdapter() if SinaAdapter is not None else None
        if s is not None:
            r = s.fetch_realtime(symbol)
            if r.get("ok"):
                price = _extract_price_from_realtime(r.get("data"))
                if price:
                    return price
    except Exception:
        pass
    # Akshare
    try:
        a = AkshareAdapter()
        r = a.fetch_realtime(symbol)
        if r.get("ok"):
            price = _extract_price_from_realtime(r.get("data"))
            if price:
                return price
    except Exception:
        pass

    return None


def check_rules_once(config: Dict[str, Any], notify_impl: Optional[StubNotify] = None) -> Dict[str, Any]:
    """Evaluate rules once and return a dict with triggers. If notify_impl is provided,
    send notifications for any alerts found.

    Positions in config may contain:
      symbol, buy_price, amount, mock_current, alert_cost_pct, alert_daily_pct
    """
    triggers: Dict[str, List[Dict[str, Any]]] = {"alerts": []}

    positions = config.get("positions", [])
    for p in positions:
        symbol = p.get("symbol")
        if not symbol:
            continue
        cost = float(p.get("buy_price") or 0)
        qty = float(p.get("amount") or 0)

        # Try to get live price from adapters first, fall back to config.mock_current
        current = None
        try:
            current = _fetch_current_price(str(symbol))
        except Exception:
            current = None
        if current is None:
            try:
                current = float(p.get("current_price") or p.get("mock_current") or 0)
            except Exception:
                current = 0.0

        # compute cost-based percentage
        if cost and current:
            pct = (current - cost) / cost * 100
            threshold = float(p.get("alert_cost_pct", 9999))
            # trigger when pct <= threshold (threshold expected negative for loss)
            if pct <= threshold:
                alert = {"symbol": symbol, "type": "cost_pct", "pct": pct, "current": current, "buy_price": cost}
                triggers["alerts"].append(alert)
                # send notification if available
                if notify_impl is not None:
                    title = f"ALERT: {symbol} cost threshold"
                    text = f"Current {current:.2f}, buy {cost:.2f}, change {pct:.2f}% (threshold {threshold}%)"
                    try:
                        notify_impl.send_text(title, text)
                    except Exception:
                        pass

        # daily pct rule (if config provides a daily_pct metric)
        try:
            daily_pct = float(p.get("daily_pct") or 0)
        except Exception:
            daily_pct = 0
        if daily_pct:
            daily_threshold = float(p.get("alert_daily_pct", 9999))
            if abs(daily_pct) >= daily_threshold:
                alert = {"symbol": symbol, "type": "daily_pct", "daily_pct": daily_pct}
                triggers["alerts"].append(alert)
                if notify_impl is not None:
                    title = f"ALERT: {symbol} daily change"
                    text = f"Daily change: {daily_pct}% (threshold {daily_threshold}%)"
                    try:
                        notify_impl.send_text(title, text)
                    except Exception:
                        pass

    return triggers


def start_daemon(config_path: str, interval: int = 60) -> None:
    if os.path.exists(PID_FILE):
        print("monitor already running")
        return

    notify_impl = StubNotify()

    def _run():
        while True:
            cfg = load_config(config_path)
            triggers = check_rules_once(cfg, notify_impl=notify_impl)
            if triggers.get("alerts"):
                print("ALERTS:", triggers["alerts"])  # also logged; notify_impl has sent notifications
            time.sleep(interval)

    t = threading.Thread(target=_run, daemon=True)
    t.start()
    # write pid file for simple control
    with open(PID_FILE, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("monitor stopped")


def stop_daemon() -> None:
    if not os.path.exists(PID_FILE):
        print("monitor not running")
        return
    try:
        with open(PID_FILE, "r", encoding="utf-8") as f:
            pid = int(f.read().strip())
        os.kill(pid, signal.SIGINT)
    except Exception:
        pass
    try:
        os.remove(PID_FILE)
    except Exception:
        pass
    print("stopped")


def status() -> None:
    if os.path.exists(PID_FILE):
        print("running")
    else:
        print("stopped")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="aksu-monitor", description="aksu-stock monitor controller")
    p.add_argument("action", choices=["start", "stop", "status", "run_once"], default="status")
    p.add_argument("--config", default="./config.example.json")
    p.add_argument("--interval", type=int, default=60)
    args = p.parse_args(argv)

    if args.action == "start":
        start_daemon(args.config, interval=args.interval)
        return 0
    if args.action == "stop":
        stop_daemon()
        return 0
    if args.action == "status":
        status()
        return 0
    if args.action == "run_once":
        cfg = load_config(args.config)
        notify_impl = StubNotify()
        triggers = check_rules_once(cfg, notify_impl=notify_impl)
        print(triggers)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
