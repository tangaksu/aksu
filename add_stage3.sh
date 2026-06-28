#!/usr/bin/env bash
set -euo pipefail

BRANCH="feature/aksu-stock-skill"
MSG="stage3: add notify base/stub, tencent adapter, config example, README"

if [ ! -d .git ]; then
  echo "请在仓库根目录运行（含 .git）"
  exit 1
fi

if git show-ref --quiet refs/heads/$BRANCH; then
  git checkout $BRANCH
else
  git checkout -b $BRANCH
fi

mkdir -p aksu-stock/notify
mkdir -p aksu-stock/adapters
mkdir -p aksu-stock/config

cat > aksu-stock/notify/base.py <<'PY'
from __future__ import annotations
from typing import Any, Dict

class NotifyBase:
    """通知抽象：实现者应提供 send_text/send_card 等方法。"""
    def send_text(self, title: str, text: str) -> bool:
        raise NotImplementedError

    def send_card(self, title: str, card_payload: Dict[str, Any]) -> bool:
        raise NotImplementedError
PY

cat > aksu-stock/notify/stub.py <<'PY'
from __future__ import annotations
import json
from .base import NotifyBase

class StubNotify(NotifyBase):
    """本地 stub 通知：只打印到 stdout，并把通知写入通知日志文件"""
    def __init__(self, log_path: str = '.aksu_notify.log'):
        self.log_path = log_path

    def send_text(self, title: str, text: str) -> bool:
        msg = f"[NOTIFY] {title}\n{text}\n"
        print(msg)
        try:
            with open(self.log_path, 'a', encoding='utf-8') as f:
                f.write(msg + '\n')
        except Exception:
            pass
        return True

    def send_card(self, title: str, card_payload: dict) -> bool:
        try:
            payload = json.dumps(card_payload, ensure_ascii=False, indent=2)
        except Exception:
            payload = str(card_payload)
        return self.send_text(title, payload)
PY

cat > aksu-stock/adapters/tencent_adapter.py <<'PY'
"""tencent 数据源适配器（骨架）。后续实现具体接口（优先用于 realtime 抓取）。"""
from __future__ import annotations
from typing import Any, Dict

class TencentAdapter:
    def __init__(self, timeout: int = 5):
        self.timeout = timeout

    def fetch_realtime(self, code: str) -> Dict[str, Any]:
        # TODO: 实现腾讯接口抓取
        return {"ok": False, "error": "tencent adapter not implemented"}

    def fetch_history(self, code: str, period: str = "60d") -> Dict[str, Any]:
        return {"ok": False, "error": "tencent adapter not implemented"}
PY

cat > aksu-stock/config/config.example.json <<'JSON'
{
  "positions": [
    {
      "symbol": "600519",
      "name": "贵州茅台",
      "buy_price": 1800.0,
      "amount": 10,
      "mock_current": 1950.0,
      "alert_cost_pct":  -10,
      "alert_daily_pct": 5
    },
    {
      "symbol": "300750",
      "name": "宁德时代",
      "buy_price": 220.0,
      "amount": 50,
      "mock_current": 240.0,
      "alert_cost_pct": -8,
      "alert_daily_pct": 6
    }
  ]
}
JSON

cat > aksu-stock/README.md <<'PY'
aksu-stock — monitor & notify 示例

运行 monitor（一次性检测）：
  python3 aksu-stock/services/monitor.py run_once --config aksu-stock/config/config.example.json

运行守护模式（简单 PID 实现）：
  ./aksu-stock/scripts/control.sh start --config aksu-stock/config/config.example.json

通知：当前默认使用 aksu-stock/notify/stub.py（本地打印）。要替换为飞书或其他实现，请实现 aksu-stock/notify/base.py 接口并在 monitor 中加载替换实现。
PY

git add aksu-stock || true
git commit -m "$MSG" || true

echo "已在本地分支 $BRANCH 创建并提交变更。"
echo "要把变更推送到远程，请运行："
echo "  git push origin $BRANCH"
