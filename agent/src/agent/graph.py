"""Deep Agent graph factory for LangGraph API server."""

from __future__ import annotations

import logging
import os

from deepagents import create_deep_agent
from langchain.agents.middleware import TodoListMiddleware
from langchain.tools import tool
from langchain_openai import ChatOpenAI

from agent.mcp_client import get_mcp_tools_sync, mcp_status
from agent.prompts import SYSTEM_PROMPT

logger = logging.getLogger(__name__)

_tools, _mcp_error = get_mcp_tools_sync()
if _mcp_error:
    logger.warning("%s", _mcp_error)
else:
    logger.info("Loaded %d MCP tools for deep agent", len(_tools))


@tool
def mcp_connection_status() -> str:
    """返回当前 MCP（Higress SSE）连接状态与已加载工具数量，用于排查网关或 Nacos 注册问题。"""
    st = mcp_status()
    if st["ready"]:
        return f"MCP 已就绪：{st['sse_url']}，共 {st['tool_count']} 个工具。"
    return f"MCP 未就绪：{st.get('error') or '无工具'}。SSE 地址：{st['sse_url']}"


def _build_model() -> ChatOpenAI:
    api_key = os.environ.get("SILICONFLOW_API_KEY") or os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "请设置 SILICONFLOW_API_KEY（或 OPENAI_API_KEY）以调用硅基流动 OpenAI 兼容接口"
        )
    return ChatOpenAI(
        model=os.environ.get("SILICONFLOW_MODEL", "deepseek-ai/DeepSeek-V3"),
        api_key=api_key,
        base_url=os.environ.get("SILICONFLOW_BASE_URL", "https://api.siliconflow.cn/v1"),
        temperature=float(os.environ.get("LLM_TEMPERATURE", "0.2")),
        # SiliconFlow streaming deltas send the tool name only in the first chunk
        # and "" afterwards; LangGraph v1 merge then drops the name.
        disable_streaming=True,
        output_version="v0",
        timeout=90.0,
        max_retries=1,
    )


def make_graph(config):  # noqa: ARG001 — LangGraph passes RunnableConfig
    """Factory referenced from langgraph.json."""
    agent_tools = list(_tools) + [mcp_connection_status]
    if not _tools:
        extra = (
            "\n\n当前 MCP 工具未加载。请先检查 Higress SSE 与 nacos-mcp-demo，"
            "必要时调用 mcp_connection_status 查看详情。"
        )
        system_prompt = SYSTEM_PROMPT + extra
    else:
        system_prompt = SYSTEM_PROMPT

    return create_deep_agent(
        model=_build_model(),
        tools=agent_tools,
        middleware=[TodoListMiddleware()],
        system_prompt=system_prompt,
    )
