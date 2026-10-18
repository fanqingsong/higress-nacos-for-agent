# Nacos MCP Deep Agent

LangGraph + Deep Agents，经 Higress SSE 调用 Spring Boot 注册的 MCP 工具。

## 本地运行

```bash
# 项目根目录 .env 中配置 SILICONFLOW_API_KEY 等
cd agent
uv sync --dev
uv run langgraph dev
```

API: http://localhost:2024
