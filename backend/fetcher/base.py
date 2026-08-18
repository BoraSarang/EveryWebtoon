from abc import ABC, abstractmethod

from models import EpisodeInfo


class Fetcher(ABC):
    @abstractmethod
    async def get_episodes(
        self, title_id: str
    ) -> list[EpisodeInfo]:
        ...

    @abstractmethod
    async def latest_episode(
        self, title_id: str
    ) -> int:
        """최신 회차 번호만 반환 — 신규 회차 확인용 경량 조회 (전체 목록 대신 1회 요청)."""
        ...

    @abstractmethod
    async def get_image_urls(
        self, title_id: str, episode_no: int
    ) -> list[str]:
        ...
