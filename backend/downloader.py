import asyncio
import random
import os
import time
import json
import urllib.request
import urllib.error
from typing import AsyncGenerator

from models import DownloadProgress


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/125.0.0.0 Safari/537.36"
)

PAGE_CONCURRENCY = 6

MAX_RETRIES = 3
RETRY_DELAY = 2.0


def get_referer(platform: str, title_id: str, episode_no: int) -> str:
    if platform == "naver":
        return f"https://comic.naver.com/webtoon/detail?titleId={title_id}&no={episode_no}"
    elif platform == "kakao":
        return f"https://page.kakao.com/content/{title_id}"
    return ""


def make_image_headers(platform: str, title_id: str, episode_no: int) -> dict:
    return {
        "Referer": get_referer(platform, title_id, episode_no),
        "User-Agent": USER_AGENT,
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
    }


def fetch_page(url: str, output_path: str, headers: dict) -> int:
    """urllib 기반 동기 이미지 다운로드 — asyncio.to_thread로 호출."""
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as resp:
            if resp.status == 200:
                data = resp.read()
                _write_file(output_path, data)
                return len(data)
            elif resp.status == 403:
                raise PermissionError(
                    f"403 Forbidden: {url[:80]} — Referer may be wrong"
                )
            elif resp.status == 404:
                raise FileNotFoundError(f"HTTP 404: {url[:80]}")
            else:
                raise IOError(f"HTTP {resp.status}: {url[:80]}")
    except urllib.error.HTTPError as e:
        if e.code == 403:
            raise PermissionError(
                f"403 Forbidden: {url[:80]} — Referer may be wrong"
            ) from e
        elif e.code == 404:
            raise FileNotFoundError(f"HTTP 404: {url[:80]}") from e
        else:
            raise IOError(f"HTTP {e.code}: {url[:80]}") from e
    except urllib.error.URLError as e:
        raise IOError(f"URLError: {e.reason}: {url[:80]}") from e
    except TimeoutError as e:
        raise TimeoutError(f"Timeout after 30s: {url[:80]}") from e


async def download_image(
    url: str,
    output_path: str,
    headers: dict,
) -> int:
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return await asyncio.to_thread(fetch_page, url, output_path, headers)
        except (TimeoutError, IOError) as e:
            if attempt < MAX_RETRIES:
                await asyncio.sleep(RETRY_DELAY * attempt)
                continue
            raise
        except (PermissionError, FileNotFoundError):
            raise


def _write_file(output_path: str, data: bytes) -> None:
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(data)


class Downloader:
    def __init__(self, output_base: str):
        self.output_base = output_base
        self._progress_callbacks: dict[str, callable] = {}

    def set_progress_callback(self, task_id: str, cb: callable):
        self._progress_callbacks[task_id] = cb

    def remove_progress_callback(self, task_id: str):
        self._progress_callbacks.pop(task_id, None)

    async def _emit_progress(self, task_id: str, progress: DownloadProgress):
        cb = self._progress_callbacks.get(task_id)
        if cb:
            cb(progress)

    async def download_episode(
        self,
        task_id: str,
        platform: str,
        title_name: str,
        title_id: str,
        episode_no: int,
        image_urls: list[str],
    ) -> str:
        if not image_urls:
            raise ValueError(f"No image URLs for episode {episode_no}")

        ep_dir = self._episode_dir(title_name, episode_no)

        partial_path = os.path.join(ep_dir, ".partial")
        done_path = os.path.join(ep_dir, ".done")
        had_done = os.path.exists(done_path)
        if had_done:
            return ep_dir

        with open(partial_path, "w") as f:
            f.write("downloading\n")

        total = len(image_urls)
        start_time = time.time()
        total_bytes = 0
        semaphore = asyncio.Semaphore(PAGE_CONCURRENCY)

        async def download_one(idx: int, image_url: str) -> tuple[int, int]:
            async with semaphore:
                ext = _guess_extension(image_url)
                output_path = os.path.join(ep_dir, f"{idx:03d}.{ext}")
                if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                    return idx, os.path.getsize(output_path)
                headers = make_image_headers(platform, title_id, episode_no)
                headers["User-Agent"] = USER_AGENT
                byte_count = await download_image(image_url, output_path, headers)
            return idx, byte_count

        try:
            tasks = [
                asyncio.ensure_future(download_one(idx, url))
                for idx, url in enumerate(image_urls, 1)
            ]
            done_count = 0
            for coro in asyncio.as_completed(tasks):
                _, byte_count = await coro
                done_count += 1
                total_bytes += byte_count

                elapsed = time.time() - start_time
                speed_bps = (total_bytes / elapsed) if elapsed > 0 else 0
                bytes_remaining = (total_bytes / done_count) * (total - done_count) if done_count > 0 else 0
                eta_sec = (bytes_remaining / speed_bps) if speed_bps > 0 else 0

                progress = DownloadProgress(
                    task_id=task_id,
                    episode_no=episode_no,
                    current_page=done_count,
                    total_pages=total,
                    speed=_format_speed(speed_bps),
                    eta=_format_time(eta_sec),
                    status="downloading" if done_count < total else "done",
                    current_bytes=total_bytes,
                    total_bytes=total_bytes + int(bytes_remaining),
                )
                await self._emit_progress(task_id, progress)
        except asyncio.CancelledError:
            for t in tasks:
                t.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            _keep_partial(ep_dir, partial_path)
            raise
        except Exception:
            for t in tasks:
                t.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            _keep_partial(ep_dir, partial_path)
            raise
        else:
            if os.path.exists(partial_path):
                os.remove(partial_path)
            with open(done_path, "w") as f:
                f.write(json.dumps({"episode_no": episode_no, "pages": total}))

        return ep_dir

    async def close(self):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        await self.close()

    def _episode_dir(self, title_name: str, episode_no: int) -> str:
        safe = _sanitize_path(title_name).rstrip(".")
        if not safe or safe in (".", "..") or ".." in safe.split(os.sep):
            safe = "unknown_title"
        ep_dir = os.path.join(self.output_base, safe, f"{episode_no:03d}")
        base = os.path.abspath(self.output_base)
        if os.path.commonpath([os.path.abspath(ep_dir), base]) != base:
            raise ValueError(f"Invalid output path for title: {title_name!r}")
        os.makedirs(ep_dir, exist_ok=True)
        return ep_dir


def _keep_partial(ep_dir: str, partial_path: str) -> None:
    """일시정지/실패 시 부분 다운로드 파일 보존 — 재개 시 이미 다운로드된 페이지는 스킵."""
    os.makedirs(ep_dir, exist_ok=True)
    with open(partial_path, "w") as f:
        f.write("partial\n")


def _sanitize_path(name: str) -> str:
    import re
    return re.sub(r'[\\/:*?"<>|]', "_", name).strip()


def _guess_extension(url: str) -> str:
    base = url.split("?")[0].rstrip("/")
    ext = os.path.splitext(base)[1].lstrip(".")
    if ext and len(ext) <= 5:
        return ext
    return "jpg"


def _format_speed(bytes_per_sec: float) -> str:
    if bytes_per_sec > 1_000_000:
        return f"{bytes_per_sec / 1_000_000:.1f} MB/s"
    elif bytes_per_sec > 1_000:
        return f"{bytes_per_sec / 1_000:.0f} KB/s"
    return f"{bytes_per_sec:.0f} B/s"


def _format_time(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"
