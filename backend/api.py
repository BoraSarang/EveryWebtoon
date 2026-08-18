import json
import sys
import traceback
from typing import AsyncGenerator

from models import JsonRpcRequest, JsonRpcResponse, webtoon_to_dict, episode_to_dict
from discovery.naver_discovery import NaverDiscoveryProvider
from discovery.kakao_discovery import KakaoDiscoveryProvider
from fetcher.naver_fetcher import NaverFetcher
from fetcher.kakao_fetcher import KakaoFetcher
from downloader import Downloader
from exporter import export_episode_cbz, export_episode_epub


DOWNLOAD_BASE = None
_downloader: Downloader | None = None


def init(output_base: str):
    global DOWNLOAD_BASE, _downloader
    DOWNLOAD_BASE = output_base
    _downloader = Downloader(output_base)


async def handle_action(
    request: JsonRpcRequest,
    progress_callback: callable = None,
) -> AsyncGenerator[JsonRpcResponse, None]:
    action = request.action
    params = request.params
    req_id = request.id

    try:
        if action == "discover":
            async for resp in _handle_discover(req_id, params):
                yield resp

        elif action == "get_episodes":
            async for resp in _handle_get_episodes(req_id, params):
                yield resp

        elif action == "latest_episode":
            resp = await _handle_latest_episode(req_id, params)
            yield resp

        elif action == "download_episode":
            async for resp in _handle_download_episode(
                req_id, params, progress_callback
            ):
                yield resp

        elif action == "cancel_download":
            yield JsonRpcResponse(id=req_id, type="error", data={"message": "Not handled here"})

        elif action == "export_episode":
            resp = await _handle_export_episode(req_id, params)
            yield resp

        else:
            yield JsonRpcResponse(
                id=req_id,
                type="error",
                data={"message": f"Unknown action: {action}"},
            )

    except Exception as e:
        traceback.print_exc(file=sys.stderr)
        yield JsonRpcResponse(
            id=req_id,
            type="error",
            data={"message": str(e), "type": type(e).__name__},
        )


async def _handle_discover(req_id: str, params: dict):
    platform = params.get("platform", "naver")
    category = params.get("category", "weekday")

    discover_params = {k: v for k, v in params.items() if k not in ("platform", "category")}

    if platform == "naver":
        provider = NaverDiscoveryProvider()
        try:
            webtoons = await provider.discover(category=category, **discover_params)
            yield JsonRpcResponse(
                id=req_id,
                type="result",
                data=[webtoon_to_dict(w) for w in webtoons],
            )
        finally:
            await provider.close()
    elif platform == "kakao":
        provider = KakaoDiscoveryProvider()
        try:
            # 랭킹/장르는 상단 추천(section_top_v2) + 전체 목록 반환
            if category in ("ranking", "genre"):
                top, main = await provider.get_landing_with_top(category, **discover_params)
                yield JsonRpcResponse(
                    id=req_id,
                    type="result",
                    data={"top": [webtoon_to_dict(w) for w in top],
                          "list": [webtoon_to_dict(w) for w in main]},
                )
            else:
                webtoons = await provider.discover(category=category, **discover_params)
                yield JsonRpcResponse(
                    id=req_id,
                    type="result",
                    data=[webtoon_to_dict(w) for w in webtoons],
                )
        finally:
            await provider.close()
    else:
        yield JsonRpcResponse(
            id=req_id,
            type="error",
            data={"message": f"Unknown platform: {platform}"},
        )


async def _handle_get_episodes(req_id: str, params: dict):
    platform = params.get("platform", "naver")
    title_id = params.get("title_id", "")

    if platform == "naver":
        fetcher = NaverFetcher()
        try:
            episodes = await fetcher.get_episodes(title_id)
            yield JsonRpcResponse(
                id=req_id,
                type="result",
                data=[episode_to_dict(e) for e in episodes],
            )
        finally:
            await fetcher.close()
    elif platform == "kakao":
        fetcher = KakaoFetcher()
        try:
            episodes = await fetcher.get_episodes(title_id)
            yield JsonRpcResponse(
                id=req_id,
                type="result",
                data=[episode_to_dict(e) for e in episodes],
            )
        finally:
            await fetcher.close()
    else:
        yield JsonRpcResponse(
            id=req_id,
            type="error",
            data={"message": f"Platform not supported: {platform}"},
        )


async def _handle_latest_episode(req_id: str, params: dict) -> JsonRpcResponse:
    platform = params.get("platform", "naver")
    title_id = params.get("title_id", "")

    if platform == "naver":
        fetcher = NaverFetcher()
        try:
            episode_no = await fetcher.latest_episode(title_id)
        finally:
            await fetcher.close()
    elif platform == "kakao":
        fetcher = KakaoFetcher()
        try:
            episode_no = await fetcher.latest_episode(title_id)
        finally:
            await fetcher.close()
    else:
        return JsonRpcResponse(
            id=req_id,
            type="error",
            data={"message": f"Platform not supported: {platform}"},
        )
    return JsonRpcResponse(
        id=req_id,
        type="result",
        data={"episode_no": episode_no},
    )


async def _handle_download_episode(
    req_id: str,
    params: dict,
    progress_callback: callable = None,
):
    platform = params.get("platform", "naver")
    title_id = params.get("title_id", "")
    title_name = params.get("title_name", title_id)
    episode_no = params.get("episode_no", 0)

    if platform == "naver":
        from fetcher.naver_fetcher import NaverFetcher
        fetcher = NaverFetcher()
    elif platform == "kakao":
        from fetcher.kakao_fetcher import KakaoFetcher
        fetcher = KakaoFetcher()
    else:
        raise ValueError(f"Unsupported platform: {platform}")
    try:
        image_urls = await fetcher.get_image_urls(title_id, episode_no)
    finally:
        await fetcher.close()

    def cb(progress):
        if progress_callback:
            progress_callback(progress)

    if _downloader is None:
        raise RuntimeError("Downloader not initialized")

    _downloader.set_progress_callback(req_id, cb)
    try:
        path = await _downloader.download_episode(
            task_id=req_id,
            platform=platform,
            title_name=title_name,
            title_id=title_id,
            episode_no=episode_no,
            image_urls=image_urls,
        )
        yield JsonRpcResponse(
            id=req_id,
            type="result",
            data={"path": path, "episode": episode_no, "pages": len(image_urls)},
        )
    finally:
        _downloader.remove_progress_callback(req_id)


async def _handle_export_episode(req_id: str, params: dict) -> JsonRpcResponse:
    title_name = params.get("title_name", "")
    episode_no = params.get("episode_no", 0)
    fmt = params.get("format", "cbz")

    if fmt not in ("cbz", "epub"):
        raise ValueError(f"Unsupported format: {fmt}")
    if not title_name:
        raise ValueError("title_name is required")
    if DOWNLOAD_BASE is None:
        raise RuntimeError("Downloader not initialized")

    if fmt == "epub":
        path = export_episode_epub(DOWNLOAD_BASE, title_name, episode_no)
    else:
        path = export_episode_cbz(DOWNLOAD_BASE, title_name, episode_no)
    return JsonRpcResponse(
        id=req_id,
        type="result",
        data={"path": path, "episode": episode_no, "format": fmt},
    )
