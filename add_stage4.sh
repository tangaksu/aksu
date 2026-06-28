#!/usr/bin/env bash
set -euo pipefail

BRANCH="feature/aksu-stock-skill"
MSG="stage4: add sina adapter, report_generator, packaging, dockerfile, tests, SKILL update"

if [ ! -d .git ]; then
  echo "请在仓库根目录运行（含 .git）"
  exit 1
fi

# switch/create branch
if git show-ref --quiet refs/heads/"$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
fi

mkdir -p aksu-stock/adapters
mkdir -p aksu-stock/services
mkdir -p aksu-stock/notify
mkdir -p aksu-stock
mkdir -p tests

# adapters __init__
cat > aksu-stock/adapters/__init__.py <<'PY'
from .akshare_adapter import AkshareAdapter
from .tencent_adapter import TencentAdapter
# 新浪适配器占位
try:
    from .sina_adapter import SinaAdapter
except Exception:
    SinaAdapter = None

__all__ = ["AkshareAdapter", "TencentAdapter", "SinaAdapter"]
PY

# sina adapter skeleton
cat > aksu-stock/adapters/sina_adapter.py <<'PY'
"""新浪数据适配器骨架（占位）。后续实现具体接口与字段映射。"""
from __future__ import annotations
from typing import Any, Dict

class SinaAdapter:
    def __init__(self, timeout: int = 5):
        self.timeout = timeout

    def fetch_realtime(self, code: str) -> Dict[str, Any]:
        # TODO: 使用新浪公开接口或抓取实现此方法
        return {"ok": False, "error": "sina adapter not implemented"}

    def fetch_history(self, code: str, period: str = "60d") -> Dict[str, Any]:
        return {"ok": False, "error": "sina adapter not implemented"}
PY

# report generator
cat > aksu-stock/services/report_generator.py <<'PY'
"""Report generator: render HTML and optionally export PDF."""
from __future__ import annotations
from typing import Dict, Any, Optional
import os

def generate_html_report(data: Dict[str, Any], title: Optional[str] = None) -> str:
    from ..renderers.html import render_analysis_html
    html = render_analysis_html(data)
    return html

def export_pdf_from_html(html: str, out_path: str) -> bool:
    """Try to export html -> pdf using pdfkit (wkhtmltopdf). If not available, return False."""
    try:
        import pdfkit
    except Exception:
        return False
    try:
        pdfkit.from_string(html, out_path)
        return True
    except Exception:
        return False
PY

# notify package init
cat > aksu-stock/notify/__init__.py <<'PY'
# notify package: provides pluggable notification implementations
from .base import NotifyBase
from .stub import StubNotify

__all__ = ["NotifyBase", "StubNotify"]
PY

# pyproject.toml
cat > pyproject.toml <<'PYT'
[project]
name = "aksu-stock"
version = "0.1.0"
description = "AKSU unified A-share skill (aggregation of akshare-stock, stock-realtime-brief, stock-monitor-pro)"
requires-python = ">=3.10"
authors = [
  { name="tangaksu", email="13686458285@163.com" }
]

[tool.poetry.dependencies]
python = "^3.10"
pandas = "*"
akshare = {version="*", optional=true}
jinja2 = {version="*", optional=true"}
pytest = {version="*", optional=true}

[build-system]
requires = ["setuptools", "wheel"]
build-backend = "setuptools.build_meta"
PYT

# Dockerfile
cat > Dockerfile <<'DOCK'
FROM python:3.10-slim
WORKDIR /app
COPY . /app
RUN pip install --no-cache-dir -U pip && pip install --no-cache-dir akshare pandas jinja2
# default command: show help
CMD ["python", "aksu-stock/main.py", "--help"]
DOCK

# SKILL.md update (append or create)
cat > aksu-stock/SKILL.md <<'MD'
---
name: aksu-stock
description: 综合 A 股技能：实时分析、持仓简报、监控与报告生成（聚合 akshare-stock, stock-realtime-brief, stock-monitor-pro）
author: tangaksu
version: "0.1.0"
tags:
  - stock
  - a-share
---

# AKSU Stock Skill

统一入口示例：
- 单股分析： python aksu-stock/main.py analyze --codes 600519
- 持仓简报： python aksu-stock/main.py portfolio --portfolio path/to/portfolio.json
- 监控： ./aksu-stock/scripts/control.sh start --config aksu-stock/config/config.example.json
- 生成报告（示例）见 services/report_generator.py
MD

# tests: analyzer extended (basic)
cat > tests/test_analyzer_extended.py <<'PY'
from aksu_stock.services.analyzer import analyze_single

def test_analyze_single_no_akshare():
