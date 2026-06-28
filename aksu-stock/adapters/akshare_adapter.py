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
            # AKShare 没有统一的 "fund_flow" 接口；这里尝试使用 stock_money_flow_by_name/stock_money_flow
            # 作为示例：
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
