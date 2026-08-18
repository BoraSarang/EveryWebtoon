import re

from bs4 import BeautifulSoup

from models import EpisodeInfo
from fetcher.base import Fetcher
from httputil import fetch_text, fetch_json


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/125.0.0.0 Safari/537.36"
)


class AdultVerificationError(ValueError):
    """네이버 성인 웹툰 — 연령 인증 게이트 페이지가 열림."""

    def __init__(self, title_id: str):
        super().__init__(
            f"AdultVerificationRequired: 성인 웹툰(연령 인증 필요) titleId={title_id}"
        )


def _is_age_gate(html: str) -> bool:
    return "연령확인이 필요해요" in html or "성인인증" in html


class NaverFetcher(Fetcher):
    BASE_URL = "https://comic.naver.com"

    async def get_episodes(self, title_id: str) -> list[EpisodeInfo]:
        url = f"{self.BASE_URL}/webtoon/detail?titleId={title_id}&no=1"

        headers = {
            "User-Agent": USER_AGENT,
            "Accept-Language": "ko-KR,ko;q=0.9",
            "Referer": f"https://comic.naver.com/webtoon/list?titleId={title_id}",
        }

        html = await fetch_text(url, headers=headers)

        if _is_age_gate(html):
            raise AdultVerificationError(title_id)

        soup = BeautifulSoup(html, "html.parser")
        area = soup.select_one(".episode_list_area")

        if not area:
            raise ValueError(
                f"Cannot find episode list area for titleId={title_id}"
            )

        seen = set()
        episodes = []

        for a in area.find_all("a", href=re.compile(r"no=\d+")):
            href = a.get("href", "")
            m = re.search(r"no=(\d+)", href)
            if not m:
                continue

            episode_no = int(m.group(1))
            if episode_no in seen:
                continue
            seen.add(episode_no)

            text = a.get_text(strip=True)
            thumb = a.select_one("img")
            title = text if text else f"{episode_no}화"

            episode = EpisodeInfo(
                webtoon_platform="naver",
                webtoon_id=title_id,
                episode_no=episode_no,
                title=title,
                thumbnail_url=thumb.get("src", "") if thumb else "",
            )
            episodes.append(episode)

        episodes.sort(key=lambda e: e.episode_no, reverse=True)
        return episodes

    async def latest_episode(self, title_id: str) -> int:
        """경량 JSON API — HTML(150~300KB) 대신 회차 목록 1페이지(약 10KB)만 조회."""
        url = f"{self.BASE_URL}/api/article/list"

        headers = {
            "User-Agent": USER_AGENT,
            "Accept-Language": "ko-KR,ko;q=0.9",
            "Referer": f"https://comic.naver.com/webtoon/detail?titleId={title_id}&no=1",
        }

        try:
            data = await fetch_json(
                url,
                params={"titleId": title_id, "page": "1"},
                headers=headers,
            )
        except IOError as e:
            if "404" in str(e):
                raise AdultVerificationError(title_id) from e
            raise

        articles = data.get("articleList") or []
        if not articles:
            raise ValueError(
                f"No articles for titleId={title_id}"
            )
        return max(a["no"] for a in articles)

    async def get_image_urls(
        self, title_id: str, episode_no: int
    ) -> list[str]:
        url = f"{self.BASE_URL}/webtoon/detail?titleId={title_id}&no={episode_no}"

        headers = {
            "User-Agent": USER_AGENT,
            "Accept-Language": "ko-KR,ko;q=0.9",
            "Referer": f"https://comic.naver.com/webtoon/list?titleId={title_id}",
        }

        html = await fetch_text(url, headers=headers)

        if _is_age_gate(html):
            raise AdultVerificationError(title_id)

        soup = BeautifulSoup(html, "html.parser")
        viewer = soup.select_one(".wt_viewer")

        if not viewer:
            raise ValueError(
                f"Cannot find .wt_viewer for titleId={title_id}, no={episode_no}"
            )

        urls = []
        for img in viewer.find_all("img"):
            src = img.get("src", "")
            if not src:
                continue
            if src.startswith("//"):
                src = "https:" + src
            urls.append(src)

        if not urls:
            for tag in soup.find_all("img"):
                src = tag.get("src", "")
                if "image-comic" in src:
                    if src.startswith("//"):
                        src = "https:" + src
                    urls.append(src)

        if not urls:
            raise ValueError(
                f"No images found for titleId={title_id}, no={episode_no}"
            )

        return urls

    async def close(self):
        pass
