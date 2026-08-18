from dataclasses import dataclass, field, asdict
from typing import Optional


@dataclass
class WebtoonInfo:
    platform: str
    platform_id: str
    title: str
    author: str
    thumbnail_url: str
    star_score: float = 0.0
    genre: str = ""
    description: str = ""
    is_adult: bool = False
    is_finished: bool = False
    is_new: bool = False
    episode_count: Optional[int] = None
    view_count: Optional[int] = None
    update_date: str = ""
    is_updated: bool = False


@dataclass
class EpisodeInfo:
    webtoon_platform: str
    webtoon_id: str
    episode_no: int
    title: str
    date: str = ""
    thumbnail_url: str = ""
    page_count: Optional[int] = None


@dataclass
class PageInfo:
    episode_platform: str
    episode_id: str
    page_no: int
    image_url: str


@dataclass
class DownloadProgress:
    task_id: str
    episode_no: int
    current_page: int
    total_pages: int
    speed: str = ""
    eta: str = ""
    status: str = "downloading"
    current_bytes: int = 0
    total_bytes: int = 0


@dataclass
class JsonRpcRequest:
    id: str
    action: str
    params: dict = field(default_factory=dict)


@dataclass
class JsonRpcResponse:
    id: str
    type: str
    data: any = None


def webtoon_to_dict(w: WebtoonInfo) -> dict:
    return asdict(w)


def episode_to_dict(e: EpisodeInfo) -> dict:
    return asdict(e)
