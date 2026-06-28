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
