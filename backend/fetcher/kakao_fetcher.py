import json
import re

from models import EpisodeInfo
from fetcher.base import Fetcher
from httputil import fetch_json


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/125.0.0.0 Safari/537.36"
)

HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
    "Referer": "https://page.kakao.com/",
    "Origin": "https://page.kakao.com",
    "Content-Type": "application/json",
}


class KakaoFetcher(Fetcher):
    API_BASE = "https://bff-page.kakao.com"

    async def get_episodes(self, title_id: str) -> list[EpisodeInfo]:
        episodes = []
        cursor_index = 0
        seen = set()

        for _ in range(10):
            try:
                data = await fetch_json(
                    f"{self.API_BASE}/api/gateway/api/v2/content/product/list",
                    params={
                        "series_id": title_id,
                        "cursor_index": str(cursor_index),
                        "cursor_direction": "ANCHOR",
                        "window_size": "30",
                    },
                    headers=HEADERS,
                )
            except IOError:
                break

            result = data.get("result", {})
            items = result.get("list", [])
            if not items:
                break

            for it in items:
                item = it.get("item", {})
                uid = item.get("uid")
                if uid is None or uid in seen:
                    continue
                seen.add(uid)
                episodes.append(EpisodeInfo(
                    webtoon_platform="kakao",
                    webtoon_id=title_id,
                    episode_no=uid,
                    title=item.get("title", ""),
                    date=(item.get("last_release_dt") or "")[:10],
                    page_count=item.get("page_count"),
                    thumbnail_url="",
                ))

            if not result.get("has_next"):
                break

            # 다음 페이지 커서: 마지막 아이템의 cursor_index 사용
            cursor_index = items[-1].get("cursor_index", 0) if items else 0

        episodes.sort(key=lambda e: e.episode_no, reverse=True)
        return episodes

    async def latest_episode(self, title_id: str) -> int:
        """경량 조회 — window_size 100으로 1페이지(최신 100개)만 받아 최대 uid 반환."""
        try:
            data = await fetch_json(
                f"{self.API_BASE}/api/gateway/api/v2/content/product/list",
                params={
                    "series_id": title_id,
                    "cursor_index": "0",
                    "cursor_direction": "ANCHOR",
                    "window_size": "100",
                },
                headers=HEADERS,
            )
        except IOError as e:
            raise IOError(f"Kakao latest episode error: {e}") from e

        items = data.get("result", {}).get("list", []) or []
        uids = [
            it.get("item", {}).get("uid")
            for it in items
            if it.get("item", {}).get("uid") is not None
        ]
        if not uids:
            raise ValueError(f"No items for series_id={title_id}")
        return max(uids)

    async def get_image_urls(self, title_id: str, episode_no: int) -> list[str]:
        try:
            data = await fetch_json(
                f"{self.API_BASE}/api/gateway/api/v1/viewer/data",
                params={"series_id": title_id, "product_id": str(episode_no)},
                headers=HEADERS,
            )
        except IOError as e:
            raise IOError(f"Kakao viewer error: {e}") from e

        result_code = data.get("result_code", -1)
        if result_code != 0:
            raise IOError(
                "카카오 회차 이미지는 로그인 인증이 필요해 다운로드할 수 없습니다 "
                "(카카오 계정 로그인이 구현되어 있지 않음)"
            )

        # 결과에서 슬라이드(이미지) URL 추출
        result = data.get("result", {})
        slide_urls = result.get("slide_urls", []) or []
        if not slide_urls:
            # slide_list 또는 이미지 필드 탐색
            for key in ("slide_list", "slides", "images", "data"):
                val = result.get(key)
                if isinstance(val, list):
                    for s in val:
                        if isinstance(s, dict):
                            for k in ("url", "image_url", "thumbnail"):
                                if s.get(k):
                                    slide_urls.append(s[k])
                                    break
                        elif isinstance(s, str):
                            slide_urls.append(s)

        urls = []
        for u in slide_urls:
            if isinstance(u, str) and u.startswith(("http", "//")):
                if u.startswith("//"):
                    u = "https:" + u
                urls.append(u)
        return urls

    async def close(self):
        pass
