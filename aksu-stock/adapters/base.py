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
