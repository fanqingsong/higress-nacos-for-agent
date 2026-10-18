#!/usr/bin/env bash
# Configure Higress MCP Bridge (MCP Server metadata is auto-registered by the app on startup).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NACOS_URL="${NACOS_URL:-http://localhost:8848}"
MCP_NAME="${MCP_NAME:-mcp-test}"
NAMESPACE="${NACOS_NAMESPACE:-public}"

if [[ "${PURGE_LEGACY_MCP:-true}" == "true" ]]; then
  echo "==> Removing legacy OpenAPI/HTTP-proxy MCP definition (if any): ${MCP_NAME}"
  MCP_JSON="$(curl -fsS "${NACOS_URL}/nacos/v3/admin/ai/mcp?namespaceId=${NAMESPACE}&mcpName=${MCP_NAME}" 2>/dev/null || true)"
  MCP_ID="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('data',{}).get('id',''))" "$MCP_JSON" 2>/dev/null || true)"
  if [[ -n "${MCP_ID}" ]]; then
    curl -fsS -X DELETE "${NACOS_URL}/nacos/v3/admin/ai/mcp" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "namespaceId=${NAMESPACE}" \
      --data-urlencode "mcpName=${MCP_NAME}" \
      --data-urlencode "mcpId=${MCP_ID}" \
      >/dev/null 2>&1 || echo "    (skip delete — will be overwritten after app registers)"
    echo "    removed mcpId: ${MCP_ID}"
  else
    echo "    no existing MCP server — app will register on startup"
  fi
fi

SECRET_NAME="nacos3-auth-local"
echo "==> Writing Higress Nacos auth secret (${SECRET_NAME})"
docker cp "$ROOT/scripts/higress-nacos-secret.yaml" "higress:/data/secrets/${SECRET_NAME}.yaml"

echo "==> Updating Higress McpBridge"
docker cp "$ROOT/scripts/higress-mcpbridge-default.yaml" higress:/data/mcpbridges/default.yaml

echo "==> Enabling MCP server in higress-config (Redis: redis:6379)"
docker exec higress sed -i \
  -e 's/enable: false/enable: true/' \
  -e 's/address: redis-address:6379/address: redis:6379/' \
  -e 's/password: ""/password: "admin1234"/' \
  /data/configmaps/higress-config.yaml

echo "==> Restarting Higress"
docker restart higress >/dev/null
sleep 12

echo "==> Verify MCP SSE endpoint (requires nacos-mcp-demo running with auto-register)"
SSE_OUT="$(curl --max-time 3 -s "http://localhost:8081/mcp/${MCP_NAME}/sse" || true)"
if echo "$SSE_OUT" | grep -q 'event: endpoint'; then
  echo "$SSE_OUT" | head -3
  echo "OK: MCP SSE 已就绪 → http://localhost:8081/mcp/${MCP_NAME}/sse"
else
  echo "WARN: SSE 未返回 endpoint 事件。请先启动/重启 nacos-mcp-demo 完成 Nacos 自动注册，稍后再试。"
  echo "      docker compose -f docker-compose.yml up -d --build"
fi
