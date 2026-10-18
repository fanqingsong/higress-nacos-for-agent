#!/usr/bin/env bash
# 检查 MCP SSE / Agent 环境，并提示或启动 Deep Agent 对话演示
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MCP_NAME="${MCP_NAME:-mcp-test}"
MCP_SSE_URL="${MCP_SSE_URL:-http://localhost:8081/mcp/${MCP_NAME}/sse}"
ENV_FILE="${ROOT}/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

echo "==> 检查 Higress MCP SSE: ${MCP_SSE_URL}"
SSE_OUT="$(curl --max-time 3 -s "${MCP_SSE_URL}" || true)"
if [[ -n "$SSE_OUT" ]] && echo "$SSE_OUT" | grep -q sessionId; then
  echo "    OK: SSE 端点可用"
else
  echo "    WARN: SSE 未就绪。请先执行："
  echo "          docker compose -f docker-compose-infra.yml up -d"
  echo "          ./build.sh && ./scripts/setup-mcp-higress.sh"
fi

if [[ -z "${SILICONFLOW_API_KEY:-}" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "    WARN: 未设置 SILICONFLOW_API_KEY（或 OPENAI_API_KEY）。请编辑 ${ENV_FILE} 或 .env.example"
else
  echo "    OK: LLM API Key 已配置"
fi

MODE="${1:-}"

if [[ "$MODE" == "docker" ]]; then
  echo "==> 使用 Docker Compose 启动 Agent + UI"
  docker compose -f "${ROOT}/docker-compose-agent.yml" up -d --build
  echo ""
  echo "对话 UI:  http://localhost:5173"
  echo "LangGraph: http://localhost:2024"
  exit 0
fi

if [[ "$MODE" == "agent" ]]; then
  echo "==> 启动 LangGraph Agent（前台）"
  cd "${ROOT}/agent"
  uv sync --dev
  exec uv run langgraph dev --host 0.0.0.0 --port 2024 --no-browser
fi

echo ""
echo "本地开发（推荐两个终端）："
echo "  终端 1: $0 agent"
echo "  终端 2: cd frontend && npm install && npm run dev"
echo ""
echo "Docker 一键："
echo "  $0 docker"
echo ""
echo "浏览器: http://localhost:5173"
