import asyncio
import re
from typing import Optional


from bs4 import BeautifulSoup

from models import WebtoonInfo
from .base import DiscoveryProvider
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

THUMB_URL = "https://dn-img-page.kakao.com/download/resource?kid={kid}&filename=th3"


class KakaoDiscoveryProvider(DiscoveryProvider):
    API_BASE = "https://bff-page.kakao.com"

    # 웹툰 메뉴 (subtab list 기준)
    SCREEN_WEBTOON_RECOMMEND = 51  # 웹툰 > 지금핫한
    SCREEN_WEBTOON_FINISHED = 89   # 웹툰 > 완결추천
    SCREEN_HOME = 46               # 추천 > 지금핫한 (랭킹 ref 포함)
    SCREEN_WEBTOON_WEEKDAY = 52    # 웹툰 > 요일 (landing/dayofweek)
    SCREEN_WEBTOON_RANKING = 93    # 웹툰 > 실시간 랭킹 (landing/ranking)
    SCREEN_WEBTOON_GENRE = 82      # 웹툰 > 장르전체 (landing/ranking)
    # 장르별 screen_uid (subtab list 기준, subcategory_uid와 다름)
    SCREEN_GENRES = {
        "0": 82,      # 전체
        "115": 59,    # 판타지
        "116": 60,    # 드라마
        "121": 57,    # 로맨스
        "69": 56,     # 로판
        "112": 62,    # 무협
        "122": 61,    # 액션
        "119": 58,    # BL
    }

    async def discover(self, category: str, **params) -> list[WebtoonInfo]:
        if category in ("home", "recommend"):
            return await self._themes_by_screen(self.SCREEN_WEBTOON_RECOMMEND)
        elif category == "ranking":
            return await self.get_ranking(**params)
        elif category == "new":
            return await self._new_releases()
        elif category == "finished":
            return await self._themes_by_screen(self.SCREEN_WEBTOON_FINISHED)
        elif category == "weekday":
            return await self.get_weekday(**params)
        elif category == "genre":
            return await self.get_genre(**params)
        else:
            return []

    async def _landing(self, path: str, **params) -> dict:
        request_params = {
            "category_uid": "10",
            "screen_uid": str(params.pop("screen_uid", "")),
            **{k: str(v) for k, v in params.items()},
        }
        data = await fetch_json(
            f"{self.API_BASE}/api/gateway/view/v1/{path}",
            params=request_params,
            headers=HEADERS,
        )
        if data.get("result_code") != 0:
            raise IOError(f"Kakao API error: {path} result_code={data.get('result_code')}")
        return data.get("result", {})

    async def get_weekday(self, week: str = "", genre: str = "", bm: str = "", **_) -> list[WebtoonInfo]:
        """카카오 요일별 (landing/dayofweek). week=1..7, 11=신작, 12=완결"""
        result = await self._landing(
            "landing/dayofweek", screen_uid=self.SCREEN_WEBTOON_WEEKDAY,
            tab_uid=week or "5", subcategory_uid=genre or "0", bm_opt=bm or "A",
        )
        if not result:
            return []
        return [w for s in result.get("list", []) if (w := _series_to_webtoon(s))]

    async def get_ranking(self, rank_type: str = "hourly", **_) -> list[WebtoonInfo]:
        """카카오 실시간 랭킹 (landing/ranking). rank_type: hourly/daily/weekly/monthly"""
        result = await self._landing(
            "landing/ranking", screen_uid=self.SCREEN_WEBTOON_RANKING,
            ranking_type=rank_type, page=1,
        )
        if not result:
            return []
        return [w for s in result.get("list", []) if (w := _series_to_webtoon(s))]

    async def get_genre(self, genre: str = "0", rank_type: str = "hourly", **_) -> list[WebtoonInfo]:
        """카카오 장르별 (landing/ranking + 장르 screen_uid). genre: 115판타지 116드라마 121로맨스 69로판 112무협 122액션 119BL"""
        screen_uid = self.SCREEN_GENRES.get(genre, self.SCREEN_WEBTOON_GENRE)
        result = await self._landing(
            "landing/ranking", screen_uid=screen_uid,
            ranking_type=rank_type, page=1,
        )
        if not result:
            return []
        return [w for s in result.get("list", []) if (w := _series_to_webtoon(s))]

    async def get_landing_with_top(self, category: str, **params) -> tuple[list[WebtoonInfo], list[WebtoonInfo]]:
        """(상단 추천, 전체 목록) — landing/ranking 계열 화면의 section_top_v2를 상단 추천으로 사용"""
        if category == "ranking":
            result = await self._landing(
                "landing/ranking", screen_uid=self.SCREEN_WEBTOON_RANKING,
                ranking_type=params.get("rank_type", "hourly"), page=1,
            )
        elif category == "genre":
            genre = params.get("genre", "0")
            screen_uid = self.SCREEN_GENRES.get(genre, self.SCREEN_WEBTOON_GENRE)
            result = await self._landing(
                "landing/ranking", screen_uid=screen_uid,
                ranking_type=params.get("rank_type", "hourly"), page=1,
            )
        else:
            return [], []
        if not result:
            return [], []

        top = [w for s in result.get("section_top_v2", []) if (w := _series_to_webtoon(s))]
        main = [w for s in result.get("list", []) if (w := _series_to_webtoon(s))]
        return top, main

    async def _layout(self, screen_uid: int) -> list[dict]:
        try:
            data = await fetch_json(
                f"{self.API_BASE}/api/gateway/view/v1/layout",
                params={"screen_uid": str(screen_uid)},
                headers=HEADERS,
            )
        except IOError:
            return []
        return data.get("result", {}).get("layout", []) or []

    async def _source(self, ref_key: str, view_type: str, additional: list[str]) -> list[dict]:
        body = {
            "reference": [{
                "view_type": view_type,
                "reference_key": ref_key,
                "additional": additional,
            }]
        }
        try:
            data = await fetch_json(
                f"{self.API_BASE}/api/gateway/view/v1/source",
                method="POST",
                data=body,
                headers=HEADERS,
            )
        except IOError:
            return []
        refs = data.get("result", {}).get("reference", {}).get(view_type, {})
        return refs.get(ref_key, []) if isinstance(refs, dict) else []

    async def _themes_by_screen(self, screen_uid: int) -> list[WebtoonInfo]:
        layout = await self._layout(screen_uid)
        series: list[WebtoonInfo] = []
        seen: set[int] = set()
        for item in layout:
            if item.get("type") != "THEME":
                continue
            view_data = item.get("view_data", {})
            ref_key = view_data.get("reference_key", "")
            additional = view_data.get("additional", [])
            if not ref_key:
                continue
            items = await self._source(ref_key, "series_card_view", additional)
            for s in items:
                webtoon = _series_to_webtoon(s)
                if webtoon and webtoon.platform_id not in seen:
                    seen.add(int(webtoon.platform_id))
                    series.append(webtoon)
        return series

    async def _new_releases(self) -> list[WebtoonInfo]:
        layout = await self._layout(self.SCREEN_WEBTOON_RECOMMEND)
        for item in layout:
            if item.get("type") != "THEME":
                continue
            title = item.get("title", "")
            if "신작" not in title:
                continue
            view_data = item.get("view_data", {})
            ref_key = view_data.get("reference_key", "")
            additional = view_data.get("additional", [])
            items = await self._source(ref_key, "series_card_view", additional)
            result = []
            for s in items:
                webtoon = _series_to_webtoon(s)
                if webtoon:
                    result.append(webtoon)
            return result
        return []

    async def close(self):
        pass


def _series_to_webtoon(s: dict) -> Optional[WebtoonInfo]:
    try:
        series_id = str(s.get("series_id", "") or "")
        if not series_id:
            scheme = s.get("scheme", "") or ""
            m = re.search(r'series_id=(\d+)', scheme)
            series_id = m.group(1) if m else ""
        title = s.get("title", "") or ""
        if not series_id or not title:
            return None
        if s.get("category") not in (None, "", "웹툰"):
            return None

        return WebtoonInfo(
            platform="kakao",
            platform_id=series_id,
            title=title,
            author=s.get("authors", ""),
            thumbnail_url=_thumb_url(s),
            star_score=0.0,
            is_adult=int(s.get("age_grade", 0) or 0) >= 19,
            is_finished=s.get("on_issue") == "N",
            is_new=bool(s.get("badge") == "BT02"),
            episode_count=None,
            genre=s.get("sub_category", ""),
            update_date=(s.get("last_slide_added_dt") or "")[:10],
        )
    except (KeyError, ValueError):
        return None


def _thumb_url(s: dict) -> str:
    kid = s.get("thumbnail", "")
    if not kid:
        asset = s.get("asset_property", {}) or {}
        kid = asset.get("card_img", "") or asset.get("banner_img", "")
    if not kid:
        card_set = asset.get("card_set", {}) or {}
        kid = card_set.get("background_img", "") or card_set.get("main_img", "")
    if not kid:
        banner_set = asset.get("banner_set", {}) or {}
        kid = banner_set.get("main_img", "") or banner_set.get("background_img", "")
    return THUMB_URL.format(kid=kid)
