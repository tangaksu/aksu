#!/usr/bin/env bash
set -euo pipefail

BRANCH="feature/aksu-stock-skill"
MSG="stage1+2: add aksu-stock adapters, services, renderers, monitor, CI, tests"

# Ensure in repository root
if [ ! -d .git ]; then
  echo "This script must be run at the root of the git repo (where .git lives)."
  exit 1
fi

# create/switch branch
if git show-ref --quiet refs/heads/$BRANCH; then
  git checkout $BRANCH
else
  git checkout -b $BRANCH
fi

# create directories
mkdir -p aksu-stock/adapters
mkdir -p aksu-stock/services
mkdir -p aksu-stock/renderers
mkdir -p aksu-stock/utils
mkdir -p aksu-stock/scripts
mkdir -p .github/workflows
mkdir -p tests

# Write files (will overwrite if exist)
cat > aksu-stock/adapters/base.py <<'PY'
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict


class DataAdapter(ABC):
    """抽象数据适配器接口。所有具体适配器（akshare/tencent/sina/ths）应实现这些方法。

    约定返回值格式（示例）：
      {"ok": True, "data": {...}} 或 {"ok": False, "error": "理由"}
    """

    @abstractmethod
    def fetch_realtime(self, code: str) -> Dict[str, Any]:
        """拉取单只股票的实时数据（最新价、涨跌幅、成交额等）。"""

    @abstractmethod
    def fetch_history(self, code: str, period: str = "60d", adjust: str = "qfq") -> Dict[str, Any]:
        """拉取历史 K 线数据，返回结构化的数据（可以包含 DataFrame 转换结果）。"""

    @abstractmethod
    def fetch_fund_flow(self, code: str) -> Dict[str, Any]:
        """拉取资金流向（主力/超大单/净流入等）。"""

    @abstractmethod
    def fetch_financials(self, code: str) -> Dict[str, Any]:
        """拉取公司财务/基本面数据（ROE/毛利率/营收等）。"""
PY

cat > aksu-stock/adapters/akshare_adapter.py <<'PY'
"""简单的 AKShare 适配器实现（骨架）。

说明：
- 这个实现尽量轻量：如果环境中没有安装 akshare，会返回错误信息而不是抛出。
- 返回值遵循 adapters.base.DataAdapter 的约定：{"ok": Bool, "data"/"error": ...}

后续会把 akshare-stock 中的具体抓取逻辑迁移到这里并增加更多字段映射与缓存。
"""
from __future__ import annotations

from typing import Any, Dict

try:
    import akshare as ak
except Exception:  # pragma: no cover - akshare may not be installed in CI
    ak = None

from ..adapters.base import DataAdapter
from ..utils.http import fetch_with_retries
from ..utils.cache import FileCache

cache = FileCache(cache_dir=".aksu_cache")


class AkshareAdapter(DataAdapter):
    """AKShare 数据适配器（最小实现）"""

    def __init__(self, timeout: int = 10):
        self.timeout = timeout

    def fetch_realtime(self, code: str) -> Dict[str, Any]:
        key = f"akshare:realtime:{code}"
        cached = cache.get(key, max_age_seconds=10)
        if cached is not None:
            return {"ok": True, "data": cached}

        if ak is None:
            return {"ok": False, "error": "akshare not installed"}

        try:
            # akshare 提供多个接口；这里使用 stock_zh_a_spot 作为示例（返回全市场），
            # 因此我们尝试用过滤取到单只股票信息。
            df = ak.stock_zh_a_spot()
            row = None
            for col in ("代码", "symbol", "code"):
                if col in df.columns:
                    row = df[df[col].astype(str).str.contains(code)].head(1)
                    if not row.empty:
                        break
            if row is None or row.empty:
                return {"ok": False, "error": "realtime: not found"}
            item = row.to_dict(orient="records")[0]
            cache.set(key, item)
            return {"ok": True, "data": {"symbol": code, "latest": item}}
        except Exception as e:
            return {"ok": False, "error": f"akshare realtime error: {e}"}

    def fetch_history(self, code: str, period: str = "60d", adjust: str = "qfq") -> Dict[str, Any]:
        key = f"akshare:history:{code}:{period}:{adjust}"
        cached = cache.get(key, max_age_seconds=3600)
        if cached is not None:
            return {"ok": True, "data": cached}

        if ak is None:
            return {"ok": False, "error": "akshare not installed"}

        try:
            # 使用 ak.stock_zh_a_hist 查询复权历史（示例）
            df = ak.stock_zh_a_hist(symbol=code, period="daily", start_date="", end_date="", adjust=adjust)
            # 返回 DataFrame 的表征；上层 analyzer 可以把 DataFrame 处理为指标
            cache.set(key, {"ok": True, "data": {"symbol": code, "history_df_head": df.head(5).to_dict(orient="records")}})
            return {"ok": True, "data": {"symbol": code, "history": df}}
        except Exception as e:
            return {"ok": False, "error": f"akshare history error: {e}"}

    def fetch_fund_flow(self, code: str) -> Dict[str, Any]:
        key = f"akshare:fundflow:{code}"
        cached = cache.get(key, max_age_seconds=300)
        if cached is not None:
            return {"ok": True, "data": cached}

        if ak is None:
            return {"ok": False, "error": "akshare not installed"}

        try:
            # AKShare 没有统一的 "fund_flow" 接口；这里尝试使用 stock_flow_concept_hist_em/类似接口作为示例
            df = ak.stock_flow_concept_hist_em(symbol=code) if hasattr(ak, "stock_flow_concept_hist_em") else None
            data = {"symbol": code, "raw": None}
            if df is not None:
                data["raw"] = df.head(5).to_dict(orient="records")
            cache.set(key, data)
            return {"ok": True, "data": data}
        except Exception as e:
            return {"ok": False, "error": f"akshare fund flow error: {e}"}

    def fetch_financials(self, code: str) -> Dict[str, Any]:
        key = f"akshare:financials:{code}"
        cached = cache.get(key, max_age_seconds=3600)
        if cached is not None:
            return {"ok": True, "data": cached}

        if ak is None:
            return {"ok": False, "error": "akshare not installed"}

        try:
            # 示例：拉取盈利预测 / 财务报表
            if hasattr(ak, "stock_financial_analysis_indicator"):
                df = ak.stock_financial_analysis_indicator(symbol=code)
                data = {"symbol": code, "financials_head": df.head(5).to_dict(orient="records")}
            else:
                data = {"symbol": code, "financials_head": None}
            cache.set(key, data)
            return {"ok": True, "data": data}
        except Exception as e:
            return {"ok": False, "error": f"akshare financials error: {e}"}
PY

cat > aksu-stock/utils/http.py <<'PY'
"""HTTP helper utilities: requests with retries, timeout and simple backoff."""
from __future__ import annotations

import time
import logging
from typing import Any, Dict, Optional

import requests

logger = logging.getLogger(__name__)

def fetch_with_retries(url: str, params: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, str]] = None,
                       timeout: int = 10, retries: int = 3, backoff_factor: float = 0.5) -> Dict[str, Any]:
    """Perform HTTP GET with simple retry and exponential backoff.

    Returns a dict: {"ok": True, "status_code": int, "text": str, "json": obj or None} or {"ok": False, "error": ...}
    """
    attempt = 0
    while attempt <= retries:
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=timeout)
            status = resp.status_code
            if status >= 200 and status < 300:
                try:
                    j = resp.json()
                except Exception:
                    j = None
                return {"ok": True, "status_code": status, "text": resp.text, "json": j}
            else:
                logger.warning("HTTP non-200 %s for %s (attempt %s)", status, url, attempt)
                return {"ok": False, "status_code": status, "error": resp.text}
        except requests.RequestException as exc:
            logger.warning("HTTP request error for %s: %s (attempt %s)", url, exc, attempt)
            err = exc
        attempt += 1
        sleep = backoff_factor * (2 ** (attempt - 1))
        time.sleep(sleep)
    return {"ok": False, "error": str(err)}
PY

cat > aksu-stock/utils/cache.py <<'PY'
"""A tiny file-backed cache used by adapters to avoid repeated heavy requests.

Behavior:
- Key is any string; stored as filename-safe hex digest.
- Values are JSON-serializable Python objects.
- TTL in seconds is honored when fetching.

This is intentionally minimal to avoid adding new dependencies.
"""
from __future__ import annotations

import json
import os
import time
import hashlib
from typing import Any, Optional


class FileCache:
    def __init__(self, cache_dir: str = ".aksu_cache"):
        self.cache_dir = cache_dir
        os.makedirs(self.cache_dir, exist_ok=True)

    def _path(self, key: str) -> str:
        h = hashlib.sha1(key.encode("utf-8")).hexdigest()
        return os.path.join(self.cache_dir, f"{h}.json")

    def set(self, key: str, value: Any) -> None:
        p = self._path(key)
        payload = {"ts": int(time.time()), "value": value}
        with open(p, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)

    def get(self, key: str, max_age_seconds: int = 60) -> Optional[Any]:
        p = self._path(key)
        if not os.path.exists(p):
            return None
        try:
            with open(p, "r", encoding="utf-8") as f:
                payload = json.load(f)
            ts = payload.get("ts", 0)
            if int(time.time()) - int(ts) > max_age_seconds:
                return None
            return payload.get("value")
        except Exception:
            return None

    def invalidate(self, key: str) -> None:
        p = self._path(key)
        try:
            if os.path.exists(p):
                os.remove(p)
        except Exception:
            pass
PY

cat > aksu-stock/services/__init__.py <<'PY'
"""Services package placeholder for aksu-stock.

后续会在 services/analyzer.py, services/monitor.py 中实现业务逻辑。
"""

__all__ = []
PY

cat > aksu-stock/services/analyzer.py <<'PY'
"""Analyzer service for aksu-stock.

Provides analyze_single, analyze_multi, analyze_portfolio functions that use DataAdapter
implementations to fetch data and produce a structured AnalysisResult. This is intentionally
minimal: it focuses on wiring adapters + renderers so the rest of the migration can
progress incrementally.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..adapters.akshare_adapter import AkshareAdapter
from ..renderers.markdown import render_analysis_markdown

class AnalysisResult:
    def __init__(self, ok: bool, data: Dict[str, Any] = None, error: Optional[str] = None):
        self.ok = ok
        self.data = data or {}
        self.error = error

def analyze_single(code: str, options: Dict[str, Any] | None = None) -> AnalysisResult:
    """Run a lightweight single-stock analysis: realtime + history + fund flow + financials.

    Returns AnalysisResult with combined data. Rendering is delegated to renderers.
    """
    adapter = AkshareAdapter()
    result: Dict[str, Any] = {"symbol": code}

    r_realtime = adapter.fetch_realtime(code)
    if not r_realtime.get("ok"):
        return AnalysisResult(False, error=f"realtime error: {r_realtime.get('error')}")
    result["realtime"] = r_realtime.get("data")

    r_history = adapter.fetch_history(code)
    if r_history.get("ok"):
        result["history_head"] = r_history.get("data")

    r_flow = adapter.fetch_fund_flow(code)
    if r_flow.get("ok"):
        result["fund_flow"] = r_flow.get("data")

    r_fin = adapter.fetch_financials(code)
    if r_fin.get("ok"):
        result["financials"] = r_fin.get("data")

    return AnalysisResult(True, data=result)

def analyze_multi(codes: List[str], options: Dict[str, Any] | None = None) -> AnalysisResult:
    adapter = AkshareAdapter()
    results: List[Dict[str, Any]] = []
    for code in codes:
        r = adapter.fetch_realtime(code)
        entry = {"code": code, "ok": r.get("ok"), "data": r.get("data"), "error": r.get("error")}
        results.append(entry)
    return AnalysisResult(True, data={"items": results})

def analyze_portfolio(portfolio_file: str) -> AnalysisResult:
    """Load a simple portfolio JSON and run per-position analyses.

    The portfolio format is expected to be like examples/portfolio_demo.json used in stock-realtime-brief.
    """
    import json

    try:
        with open(portfolio_file, "r", encoding="utf-8") as f:
            portfolio = json.load(f)
    except Exception as e:
        return AnalysisResult(False, error=f"failed to load portfolio: {e}")

    positions = portfolio.get("positions", [])
    adapter = AkshareAdapter()
    report = {"positions": []}
    for pos in positions:
        code = str(pos.get("symbol") or pos.get("symbol"))
        r = adapter.fetch_realtime(code)
        report_entry = {"position": pos, "realtime": r}
        report["positions"].append(report_entry)

    return AnalysisResult(True, data=report)

def render_single_markdown(result: AnalysisResult) -> str:
    if not result.ok:
        return f"Error: {result.error}"
    return render_analysis_markdown(result.data)
PY

cat > aksu-stock/renderers/markdown.py <<'PY'
"""Markdown renderer for analysis results.

This module contains a small, dependency-free renderer that creates human-readable
markdown summaries from the AnalysisResult.data structure produced by services.analyzer.
"""
from __future__ import annotations

from typing import Any, Dict

def _fmt_price(x: Any) -> str:
    try:
        return f"{float(x):.2f}"
    except Exception:
        return str(x)

def render_analysis_markdown(data: Dict[str, Any]) -> str:
    """Render a simple markdown summary for a single-stock analysis data object."""
    lines = []
    symbol = data.get("symbol") or "unknown"
    lines.append(f"# 分析：{symbol}")

    realtime = data.get("realtime")
    if realtime and isinstance(realtime, dict):
        latest = realtime.get("latest") or {}
        name = latest.get("名称") or latest.get("name") or latest.get("股票简称") or ""
        price = latest.get("最新价") or latest.get("收盘") or latest.get("price")
        pct = latest.get("涨跌幅") or latest.get("涨跌幅%") or ""
        lines.append(f"\n**实时**: {name} {symbol} 价格: {_fmt_price(price)} ({pct})")

    hist = data.get("history_head")
    if hist:
        lines.append("\n**历史（示例）**:\n```")
        try:
            # history_head may be a dataframe head converted to dict
            if isinstance(hist, dict) and "history_df_head" in hist:
                for r in hist.get("history_df_head", []):
                    lines.append(str(r))
            else:
                lines.append(str(hist))
        except Exception:
            lines.append(str(hist))
        lines.append("```")

    fund_flow = data.get("fund_flow")
    if fund_flow:
        lines.append("\n**资金流向（示例）**:")
        lines.append(str(fund_flow.get("raw") or "无"))

    financials = data.get("financials")
    if financials:
        lines.append("\n**基本面（示例）**:")
        lines.append(str(financials.get("financials_head") or "无"))

    return "\n".join(lines)
PY

cat > aksu-stock/renderers/html.py <<'PY'
"""HTML renderer for analysis + report generation.

This file uses jinja2 if available; otherwise falls back to a minimal HTML builder.
"""
from __future__ import annotations

from typing import Any, Dict

def render_analysis_html(data: Dict[str, Any]) -> str:
    try:
        import jinja2
    except Exception:  # pragma: no cover - optional dependency
        jinja2 = None

    title = f"分析：{data.get('symbol', '未知')}"

    if jinja2 is not None:
        tpl = jinja2.Template("""
        <!doctype html>
        <html>
        <head><meta charset="utf-8"><title>{{ title }}</title></head>
        <body>
        <h1>{{ title }}</h1>
        <pre>{{ payload }}</pre>
        </body>
        </html>
        """)
        return tpl.render(title=title, payload=data)

    # fallback
    body = f"<h1>{title}</h1>\n<pre>{data}</pre>"
    return f"<!doctype html><html><head><meta charset=\"utf-8\"></head><body>{body}</body></html>"
PY

cat > aksu-stock/services/monitor.py <<'PY'
"""Monitor service script (long-running) entrypoints.

This module implements a minimal rule engine and a CLI-compatible controller that
supports run-once (check) and start/stop/status via a simple PID file. It is intentionally
lightweight: production use should replace the PID-based daemon with systemd/container orchestration.
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import threading
import time
from typing import Any, Dict

PID_FILE = ".aksu_monitor.pid"

def load_config(path: str) -> Dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def check_rules_once(config: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluate rules once and return a dict with triggers.

    For now we implement simple checks: cost_pct and daily_pct for positions.
    """
    triggers = {"alerts": []}
    positions = config.get("positions", [])
    for p in positions:
        symbol = p.get("symbol")
        cost = float(p.get("buy_price") or 0)
        qty = float(p.get("amount") or 0)
        # Here we can't fetch real price without adapters; for now just demonstrate with config field "current_price"
        current = float(p.get("current_price") or p.get("mock_current") or 0)
        if cost and current:
            pct = (current - cost) / cost * 100
            if pct <= -float(p.get("alert_cost_pct", 9999)):
                triggers["alerts"].append({"symbol": symbol, "type": "cost_pct", "pct": pct})
        # daily pct trigger (configurable)
        daily_pct = float(p.get("daily_pct") or 0)
        if daily_pct and abs(daily_pct) >= float(p.get("alert_daily_pct", 9999)):
            triggers["alerts"].append({"symbol": symbol, "type": "daily_pct", "daily_pct": daily_pct})
    return triggers

def start_daemon(config_path: str, interval: int = 60) -> None:
    if os.path.exists(PID_FILE):
        print("monitor already running")
        return

    def _run():
        while True:
            cfg = load_config(config_path)
            triggers = check_rules_once(cfg)
            if triggers.get("alerts"):
                print("ALERTS:", triggers["alerts"])  # in future send to notify
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
        triggers = check_rules_once(cfg)
        print(triggers)
        return 0
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
PY

cat > aksu-stock/scripts/control.sh <<'PY'
#!/usr/bin/env bash
set -e
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CMD="python3 $ROOT_DIR/aksu-stock/services/monitor.py"
case "$1" in
  start)
    shift
    echo "Starting monitor..."
    $CMD start "$@" &
    ;;
  stop)
    echo "Stopping monitor..."
    $CMD stop
    ;;
  status)
    $CMD status
    ;;
  run_once)
    $CMD run_once "$@"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|run_once} [--config path]"
    exit 2
    ;;
esac
PY
chmod +x aksu-stock/scripts/control.sh

cat > .github/workflows/ci.yml <<'YML'
name: CI

on:
  push:
    branches: [ main, feature/aksu-stock-skill ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.10, 3.11]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install deps
        run: |
          python -m pip install --upgrade pip
          pip install pytest
      - name: Run tests
        run: |
          pytest -q
YML

cat > tests/test_smoke.py <<'PY'
def test_adapters_base_exists():
    import importlib
    m = importlib.import_module('aksu-stock.adapters.base')
    assert hasattr(m, 'DataAdapter')
PY

# Add files to git and commit
git add aksu-stock .github/workflows tests || true
git commit -m "$MSG" || true

echo "Files created and committed on branch $BRANCH."
echo "To push to remote: git push origin $BRANCH"
