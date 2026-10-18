#!/usr/bin/env bash
# Configure Nacos MCP tools (from OpenAPI) and Higress MCP Bridge.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NACOS_URL="${NACOS_URL:-http://localhost:8848}"
MCP_NAME="${MCP_NAME:-mcp-test}"
NAMESPACE="${NACOS_NAMESPACE:-public}"

echo "==> Generating toolSpecification from openapi-spec.json"
TOOL_SPEC="$("$ROOT/scripts/openapi_to_nacos_tools.py")"
TOOL_COUNT="$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])['tools']))" "$TOOL_SPEC")"
echo "    tools: $TOOL_COUNT"

echo "==> Fetching MCP server id"
MCP_JSON="$(curl -fsS "${NACOS_URL}/nacos/v3/admin/ai/mcp?namespaceId=${NAMESPACE}&mcpName=${MCP_NAME}")"
MCP_ID="$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['id'])" <<<"$MCP_JSON")"
echo "    mcpId: $MCP_ID"

SERVER_SPEC='{"name":"'"$MCP_NAME"'","protocol":"http","frontProtocol":"mcp-sse","description":"用户管理、订单管理、员工岗位查询","enabled":true,"version":"1.0.0","remoteServerConfig":{"exportPath":"/mcp","serviceRef":{"namespaceId":"public","groupName":"DEFAULT_GROUP","serviceName":"nacos-mcp-demo","transportProtocol":"http"}}}'
ENDPOINT_SPEC='{"type":"REF","data":{"namespaceId":"public","groupName":"DEFAULT_GROUP","serviceName":"nacos-mcp-demo"}}'

echo "==> Updating MCP tools in Nacos"
curl -fsS -X PUT "${NACOS_URL}/nacos/v3/admin/ai/mcp" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "namespaceId=${NAMESPACE}" \
  --data-urlencode "mcpName=${MCP_NAME}" \
  --data-urlencode "mcpId=${MCP_ID}" \
  --data-urlencode "latest=true" \
  --data-urlencode "overrideExisting=true" \
  --data-urlencode "serverSpecification=${SERVER_SPEC}" \
  --data-urlencode "endpointSpecification=${ENDPOINT_SPEC}" \
  --data-urlencode "toolSpecification=${TOOL_SPEC}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('code')==0, d; print('    Nacos update:', d.get('message'))"

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

echo "==> Verify MCP SSE endpoint"
SSE_OUT="$(curl --max-time 3 -s "http://localhost:8081/mcp/${MCP_NAME}/sse" || true)"
if echo "$SSE_OUT" | grep -q 'event: endpoint'; then
  echo "$SSE_OUT" | head -3
  echo "OK: MCP SSE 已就绪 → http://localhost:8081/mcp/${MCP_NAME}/sse"
else
  echo "WARN: SSE 未返回 endpoint 事件，请稍等后重试或查看 docker logs higress --tail 50"
fi
