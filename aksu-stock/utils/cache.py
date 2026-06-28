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
