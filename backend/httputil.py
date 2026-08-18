"""표준 라이브러리만 사용하는 비동기 HTTP 유틸 — iOS(PythonKit)와 macOS(venv) 공용.

aiohttp/lxml/Pillow 등 C 확장 의존을 제거하기 위한 순수 파이썬 계층.
urllib은 연결 재사용을 하지 않지만, 페이지/요청별 단발 호출이 대부분이라 충분.
"""

import asyncio
import json
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 30


def _build_url(url: str, params: dict | None) -> str:
    if not params:
        return url
    qs = urllib.parse.urlencode(params)
    return f"{url}?{qs}" if "?" not in url else f"{url}&{qs}"


def _request(
    method: str,
    url: str,
    params: dict | None,
    headers: dict | None,
    data: dict | list | bytes | None,
) -> bytes:
    full_url = _build_url(url, params)
    body = None
    if data is not None:
        body = (
            json.dumps(data).encode("utf-8")
            if isinstance(data, (dict, list))
            else data
        )
    req = urllib.request.Request(
        full_url, data=body, method=method, headers=headers or {}
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            if resp.status != 200:
                raise IOError(f"HTTP {resp.status}: {full_url[:80]}")
            return resp.read()
    except urllib.error.HTTPError as e:
        raise IOError(f"HTTP {e.code}: {full_url[:80]}") from e
    except urllib.error.URLError as e:
        raise IOError(f"URLError: {e.reason}: {full_url[:80]}") from e


async def fetch_bytes(
    url: str,
    params: dict | None = None,
    headers: dict | None = None,
    method: str = "GET",
    data: dict | list | bytes | None = None,
) -> bytes:
    return await asyncio.to_thread(_request, method, url, params, headers, data)


async def fetch_text(
    url: str,
    params: dict | None = None,
    headers: dict | None = None,
) -> str:
    raw = await fetch_bytes(url, params=params, headers=headers)
    return raw.decode("utf-8", errors="replace")


async def fetch_json(
    url: str,
    params: dict | None = None,
    headers: dict | None = None,
    method: str = "GET",
    data: dict | list | bytes | None = None,
) -> dict:
    raw = await fetch_bytes(url, params=params, headers=headers, method=method, data=data)
    return json.loads(raw.decode("utf-8"))
