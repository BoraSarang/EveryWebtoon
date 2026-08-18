#!/usr/bin/env python3
import asyncio
import json
import sys
import os
import traceback

from models import JsonRpcRequest, JsonRpcResponse
from api import init, handle_action


DEFAULT_OUTPUT = os.path.expanduser("~/Documents/EveryWebtoon/")

active_tasks: dict[str, asyncio.Task] = {}


async def main_loop():
    output_base = os.environ.get("EVERYWEBTOON_OUTPUT", DEFAULT_OUTPUT)
    os.makedirs(output_base, exist_ok=True)
    init(output_base)

    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)

    writer = sys.stdout

    while True:
        try:
            line = await reader.readline()
        except (EOFError, ConnectionError):
            break

        if not line:
            if active_tasks:
                await asyncio.gather(*active_tasks.values(), return_exceptions=True)
            break

        raw = line.decode("utf-8").strip()
        if not raw:
            continue

        try:
            req_data = json.loads(raw)
            request = JsonRpcRequest(
                id=req_data.get("id", ""),
                action=req_data.get("action", ""),
                params=req_data.get("params", {}),
            )
        except json.JSONDecodeError as e:
            _write_json(writer, {
                "id": "",
                "type": "error",
                "data": {"message": f"Invalid JSON: {e}"},
            })
            continue

        req_id = request.id

        if request.action == "cancel_download":
            target = request.params.get("task_id", "")
            task = active_tasks.get(target)
            if task:
                task.cancel()
            _write_json(writer, {
                "id": req_id,
                "type": "result",
                "data": {"ok": task is not None},
            })
            continue

        task = asyncio.create_task(_handle_request(req_id, request))
        active_tasks[req_id] = task
        task.add_done_callback(lambda t, rid=req_id: active_tasks.pop(rid, None))


async def _handle_request(req_id: str, request: JsonRpcRequest):
    def progress_cb(progress):
        _write_json(sys.stdout, {
            "id": req_id,
            "type": "progress",
            "data": {
                "task_id": progress.task_id,
                "episode_no": progress.episode_no,
                "current_page": progress.current_page,
                "total_pages": progress.total_pages,
                "speed": progress.speed,
                "eta": progress.eta,
                "status": progress.status,
                "current_bytes": progress.current_bytes,
                "total_bytes": progress.total_bytes,
            },
        })

    try:
        async for response in handle_action(request, progress_cb):
            _write_json(sys.stdout, {
                "id": response.id,
                "type": response.type,
                "data": response.data,
            })
    except asyncio.CancelledError:
        _write_json(sys.stdout, {
            "id": req_id,
            "type": "result",
            "data": {"cancelled": True},
        })
        raise
    except Exception as e:
        _write_json(sys.stdout, {
            "id": req_id,
            "type": "error",
            "data": {"message": str(e), "type": type(e).__name__},
        })


def _write_json(writer, obj: dict):
    line = json.dumps(obj, ensure_ascii=False, default=str) + "\n"
    writer.write(line)
    writer.flush()


if __name__ == "__main__":
    asyncio.run(main_loop())
