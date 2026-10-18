#!/bin/bash

# =============================================================================
# 构建和部署脚本
# =============================================================================
# 功能：Maven 打包 + Docker 构建 + 容器管理
#
# 使用方法:
#   ./build.sh                    # 完整构建并启动
#   ./build.sh package            # 仅 Maven 打包
#   ./build.sh build              # 打包 + 构建镜像
#   ./build.sh up                 # 启动服务
#   ./build.sh down               # 停止服务
#   ./build.sh status             # 查看服务状态
#   ./build.sh logs [service]     # 查看日志
# =============================================================================

set -e

COMPOSE_FILE="docker-compose.yml"
SERVICE="nacos-mcp-demo"

echo "================================================================"
echo "  Nacos MCP Demo 构建脚本"
echo "================================================================"
echo ""

package() {
  echo "=== 1/3 Maven 打包 ==="
  mvn clean package -DskipTests
  echo "✅ 打包完成"
  echo ""
}

build_image() {
  echo "=== 2/3 构建 Docker 镜像 ==="
  docker compose -f $COMPOSE_FILE build
  echo "✅ 镜像构建完成"
  echo ""
}

up_service() {
  echo "=== 3/3 启动服务 ==="
  docker compose -f $COMPOSE_FILE up -d
  echo "✅ 服务已启动"
  echo ""
  show_status
}

down_all() {
  echo "=== 停止服务 ==="
  docker compose -f $COMPOSE_FILE down
  echo "✅ 服务已停止"
  echo ""
}

show_status() {
  echo "等待服务启动..."
  sleep 5

  echo "=== 服务状态 ==="
  docker ps --filter "name=nacos-mcp-demo" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  echo ""

  echo "=== 最近日志 ==="
  docker logs $SERVICE --tail 5 2>&1 | grep -E "(Started|register)" || true
  echo ""
}

show_help() {
  echo "用法: $0 {package|build|up|down|status|logs|all}"
  echo ""
  echo "  package  - 仅 Maven 打包"
  echo "  build    - 打包 + 构建镜像"
  echo "  up       - 启动应用容器"
  echo "  down     - 停止应用容器"
  echo "  status   - 查看服务状态"
  echo "  logs     - 查看服务日志（默认 $SERVICE）"
  echo "  all      - 完整构建并启动（默认）"
  exit 1
}

show_logs() {
  local service=${1:-$SERVICE}
  docker logs -f $service
}

case "${1:-all}" in
  package)
    package
    ;;
  build)
    package
    build_image
    ;;
  up)
    up_service
    ;;
  down)
    down_all
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs "$2"
    ;;
  all|"")
    package
    build_image
    up_service
    ;;
  *)
    show_help
    ;;
esac

echo "================================================================"
echo "  构建完成!"
echo "================================================================"
echo ""
echo "服务地址: http://localhost:8082"
echo ""
echo "API 测试:"
echo "  用户: curl http://localhost:8082/api/users"
echo "  订单: curl http://localhost:8082/api/orders"
echo "  员工: curl 'http://localhost:8082/api/employee/position?name=张伟'"
echo ""
