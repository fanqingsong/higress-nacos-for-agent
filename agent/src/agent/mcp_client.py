"""Long-lived MCP connection to Higress SSE endpoint."""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

_default_sse_url = "http://localhost:8081/mcp/mcp-test/sse"

_adapter: Any | None = None
_tools: list[Any] | None = None
_init_error: str | None = None
_lock = asyncio.Lock()


def mcp_sse_url() -> str:
    name = os.environ.get("MCP_SERVER_NAME", "mcp-test")
    return os.environ.get("MCP_SSE_URL", f"http://localhost:8081/mcp/{name}/sse")


async def _connect() -> tuple[list[Any], str | None]:
    url = mcp_sse_url()
    try:
        from fastmcp.client import Client
        from fastmcp.client.transports import SSETransport
        from langchain.mcp import MCPAdapter

        client = Client(SSETransport(url))
        adapter = MCPAdapter(client)
        await adapter.__aenter__()
        tools = await adapter.list_tools()
        global _adapter
        _adapter = adapter
        logger.info("MCP connected: %s — %d tools", url, len(tools))
        return tools, None
    except Exception as exc:  # noqa: BLE001 — surface connection errors to operators
        msg = f"MCP SSE 连接失败 ({url}): {exc}"
        logger.error(msg)
        return [], msg


async def get_mcp_tools_async() -> tuple[list[Any], str | None]:
    global _tools, _init_error
    async with _lock:
        if _tools is not None:
            return _tools, _init_error
        _tools, _init_error = await _connect()
        return _tools, _init_error


def get_mcp_tools_sync() -> tuple[list[Any], str | None]:
    global _tools, _init_error
    if _tools is not None:
        return _tools, _init_error
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # LangGraph worker may already have a loop; schedule is unsafe here — use cached only
            return _tools or [], _init_error or "MCP 尚未初始化，请重启 Agent 服务"
        return loop.run_until_complete(get_mcp_tools_async())
    except RuntimeError:
        return asyncio.run(get_mcp_tools_async())


def mcp_status() -> dict[str, Any]:
    tools, err = get_mcp_tools_sync()
    return {
        "sse_url": mcp_sse_url(),
        "tool_count": len(tools),
        "ready": err is None and len(tools) > 0,
        "error": err,
        "tool_names": [getattr(t, "name", str(t)) for t in tools[:32]],
    }
