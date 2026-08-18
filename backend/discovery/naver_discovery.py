import re
from typing import Optional

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
    "Accept-Language": "ko-KR,ko;q=0.9",
    "Referer": "https://comic.naver.com/webtoon",
}

NAVER_GENRES = {
    "PURE": "로맨스",
    "FANTASY": "판타지",
    "ACTION": "액션",
    "DAILY": "일상",
    "THRILL": "스릴러",
    "COMIC": "개그",
    "HISTORICAL": "무협/사극",
    "DRAMA": "드라마",
    "SENSIBILITY": "감성",
    "SPORTS": "스포츠",
}

# 웹 API에서 지원하는 정렬값
ORDER_MAP = {
    "user": "USER",
    "star": "STAR",
    "update": "UPDATE",
    "popular": "VIEW",
}


class NaverDiscoveryProvider(DiscoveryProvider):
    BASE_URL = "https://comic.naver.com"

    async def discover(
        self, category: str, **params
    ) -> list[WebtoonInfo]:
        if category == "weekday":
            return await self.get_weekday(**params)
        elif category == "best_challenge":
            return await self.get_best_challenge(**params)
        elif category == "ranking":
            return await self.get_ranking(**params)
        elif category == "finished":
            return await self.get_finished(**params)
        elif category == "genre":
            return await self.get_genre(**params)
        else:
            return []

    async def get_weekday(
        self, week: str = "mon", order: str = "user"
    ) -> list[WebtoonInfo]:
        url = f"{self.BASE_URL}/api/webtoon/titlelist/weekday?week={week}&order={_order(order)}"
        data = await fetch_json(url, headers=HEADERS)

        result = []
        for item in data.get("titleList", []):
            webtoon = _item_to_webtoon(item)
            if webtoon:
                result.append(webtoon)

        return result

    async def get_finished(
        self, page: int = 1, order: str = "user", page_size: int = 25
    ) -> list[WebtoonInfo]:
        url = (
            f"{self.BASE_URL}/api/webtoon/titlelist/finished?"
            f"page={page}&pageSize={page_size}&order={_order(order)}"
        )
        data = await fetch_json(url, headers=HEADERS)

        result = []
        for item in data.get("titleList", []):
            webtoon = _item_to_webtoon(item)
            if webtoon:
                result.append(webtoon)

        return result

    async def get_best_challenge(
        self, page: int = 1, order: str = "update"
    ) -> list[WebtoonInfo]:
        order = "UPDATE" if order in ("USER", "user") else _order(order)
        url = f"{self.BASE_URL}/api/bestChallenge/list?page={page}&order={order}"
        data = await fetch_json(url, headers=HEADERS)

        result = []
        for item in data.get("list", []):
            webtoon = WebtoonInfo(
                platform="naver",
                platform_id=str(item["titleId"]),
                title=item["titleName"],
                author=_author_str(item.get("author")),
                thumbnail_url=item.get("thumbnailUrl", ""),
                star_score=item.get("starScore", 0.0) or 0.0,
                is_adult=bool(item.get("adult", False)),
                is_finished=bool(item.get("finish", False)),
                is_new=bool(item.get("new", False)),
            )
            result.append(webtoon)

        return result

    async def get_ranking(
        self, rank_tab: str = "DEFAULT", **_
    ) -> list[WebtoonInfo]:
        url = f"{self.BASE_URL}/api/realtime/ranking/list?rankTabType={rank_tab}"
        data = await fetch_json(url, headers=HEADERS)

        result = []
        for item in data.get("totalRankingTitleList", []):
            webtoon = WebtoonInfo(
                platform="naver",
                platform_id=str(item["titleId"]),
                title=item["titleName"],
                author=_author_str(item.get("displayAuthor")),
                thumbnail_url=item.get("thumbnailUrl", ""),
            )
            result.append(webtoon)

        return result

    async def get_genre(
        self,
        genre: str = "PURE",
        order: str = "user",
        page: int = 1,
        page_size: int = 25,
        year: str = "",
    ) -> list[WebtoonInfo]:
        url = (
            f"{self.BASE_URL}/api/webtoon/titlelist/genre?"
            f"type=GENRE&genre={genre}&page={page}&pageSize={page_size}&order={_order(order)}"
        )
        data = await fetch_json(url, headers=HEADERS)

        result = []
        for item in data.get("titleList", []):
            webtoon = _item_to_webtoon(item)
            if webtoon:
                result.append(webtoon)

        return result

    async def close(self):
        pass


def _order(order: str) -> str:
    if order in ORDER_MAP:
        return ORDER_MAP[order]
    if order in ORDER_MAP.values():
        return order
    return "USER"


def _author_str(author) -> str:
    if isinstance(author, str):
        return author
    if isinstance(author, dict):
        for key in ("displayAuthor", "name", "writers"):
            val = author.get(key)
            if isinstance(val, str):
                return val
            if isinstance(val, list) and val:
                first = val[0]
                if isinstance(first, dict):
                    return first.get("name", "")
                return str(first)
    return ""


def _item_to_webtoon(item: dict) -> Optional[WebtoonInfo]:
    try:
        title_id = str(item["titleId"])
    except (KeyError, TypeError):
        return None

    return WebtoonInfo(
        platform="naver",
        platform_id=title_id,
        title=item.get("titleName", ""),
        author=_author_str(item.get("displayAuthor") or item.get("author")),
        thumbnail_url=item.get("thumbnailUrl", ""),
        star_score=item.get("starScore", 0.0) or 0.0,
        is_adult=bool(item.get("adult", False)),
        is_finished=bool(item.get("finish", False)),
        is_new=bool(item.get("new", False)),
        episode_count=item.get("episodeCount"),
        view_count=item.get("viewCount"),
        genre=_genre_name(item.get("genre")),
        is_updated=bool(item.get("up", False)),
    )


def _genre_name(genre_code) -> str:
    if isinstance(genre_code, str) and genre_code in NAVER_GENRES:
        return NAVER_GENRES[genre_code]
    return ""
