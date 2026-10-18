#!/usr/bin/env bash
# 启动并校验 Nacos MCP Router（Router / 可选 Proxy 模式）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_INFRA="${ROOT}/docker-compose-infra.yml"
NACOS_URL="${NACOS_URL:-http://localhost:8848}"
MCP_NAME="${MCP_NAME:-mcp-test}"
ENABLE_PROXY="${ENABLE_MCP_ROUTER_PROXY:-false}"

echo "==> 启动 Nacos MCP Router（streamableHTTP / router 模式，端口 8000）"
docker compose -f "$COMPOSE_INFRA" up -d nacos-mcp-router

if [[ "${ENABLE_PROXY}" == "true" ]]; then
  echo "==> 启动 Proxy 模式（PROXIED_MCP_NAME=${MCP_NAME}，端口 8002）"
  docker compose -f "$COMPOSE_INFRA" --profile mcp-proxy up -d nacos-mcp-router-proxy
fi

echo "==> 等待 Router 就绪"
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null -m 2 "http://localhost:8000/mcp" 2>/dev/null \
    || curl -fsS -o /dev/null -m 2 "http://localhost:8000/sse" 2>/dev/null; then
    break
  fi
  sleep 2
done

echo "==> 检查 Nacos 中是否已有 MCP Server: ${MCP_NAME}"
MCP_JSON="$(curl -fsS "${NACOS_URL}/nacos/v3/admin/ai/mcp?namespaceId=public&mcpName=${MCP_NAME}" 2>/dev/null || echo '{}')"
if python3 -c "import json,sys; d=json.loads(sys.argv[1]); exit(0 if d.get('data',{}).get('name') else 1)" "$MCP_JSON" 2>/dev/null; then
  echo "    OK: ${MCP_NAME} 已在 Nacos 注册（Router 可通过 search_mcp_server / add_mcp_server 使用）"
else
  echo "    WARN: 未找到 ${MCP_NAME}。请先启动 nacos-mcp-demo："
  echo "          docker compose -f docker-compose.yml up -d --build"
fi

echo ""
echo "Nacos MCP Router 端点："
echo "  streamableHTTP: http://localhost:8000/mcp"
echo "  SSE:            http://localhost:8000/sse"
echo ""
echo "Router 模式工具：search_mcp_server、add_mcp_server、use_tool"
echo "客户端配置示例：scripts/mcp-client-nacos-router.json"
if [[ "${ENABLE_PROXY}" == "true" ]]; then
  echo "Proxy 模式（${MCP_NAME}）: http://localhost:8002/mcp"
fi
