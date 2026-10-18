# Higress MCP 部署问题排查与解决方案

## 部署架构

```
┌─────────────────────────────────────────┐
│         Docker Network: mcp-net         │
│                                         │
│  ┌────────────────────┐                 │
│  │ nacos-mcp-demo     │ 172.22.0.x:8082│
│  │ (后端服务)          │ ← 通过容器名访问  │
│  └────────┬───────────┘                 │
│           │                             │
│  ┌────────▼───────────┐                 │
│  │ nacos-standalone   │ 172.22.0.x:8848│
│  │ (Nacos 注册中心)    │                 │
│  └────────┬───────────┘                 │
│           │                             │
│  ┌────────▼───────────┐                 │
│  │ higress            │ 172.22.0.x:8080│
│  │ (MCP 网关)          │                 │
│  └────────┬───────────┘                 │
│           │                             │
│  ┌────────▼───────────┐                 │
│  │ mysql              │ 172.22.0.x:3306│
│  │ (Nacos 持久化)      │                 │
│  └────────┬───────────┘                 │
│           │                             │
│  ┌────────▼───────────┐                 │
│  │ redis              │ 172.22.0.x:6379│
│  │ (MCP 状态存储)      │                 │
│  └────────────────────┘                 │
└─────────────────────────────────────────┘
```

## 端口映射

| 容器 | 容器端口 | 宿主机端口 | 用途 |
|------|---------|----------|------|
| higress | 8001 | 8001 | Higress 控制台 |
| higress | 8080 | 8081 | HTTP 网关（MCP SSE 入口） |
| higress | 8443 | 8443 | HTTPS 网关 |
| nacos-standalone | 8848 | 8848 | Nacos 主端口 |
| nacos-standalone | 9848 | 9848 | Nacos gRPC 端口 |
| nacos-standalone | 8080 | 8080 | Nacos 控制台 |
| mysql | 3306 | 3306 | MySQL 数据库 |
| redis | 6379 | 6379 | Redis 缓存 |
| nacos-mcp-demo | 8082 | 8082 | 后端服务 |
| nacos-mcp-router | 8000 | 8000 | Nacos MCP Router（streamableHTTP `/mcp`） |
| nacos-mcp-router-proxy | 8000 | 8002 | MCP Router Proxy 模式（可选 profile `mcp-proxy`） |

Router 工作原理与 Agent 使用步骤见 **[NACOS-MCP-ROUTER.md](./NACOS-MCP-ROUTER.md)**。

---

## 问题记录与解决方案

### 问题 1：MCP SSE 端点 404

**现象**：访问 `http://localhost:8081/mcp/mcp-test/sse` 返回 404

**原因**：McpBridge 配置中 `enableMCPServer: false`

**解决**：在 Higress 控制台将 Nacos 注册中心的 `enableMCPServer` 改为 `true`

---

### 问题 2：Higress 无法从 Nacos 拉取 MCP 配置（403 认证失败）

**现象**：Controller 日志持续报错
```
error McpServer List mcp server configs error: [403] User not found!
path: /nacos/v3/admin/cs/config/list
```

**原因**：Nacos 3.1.2 的 `nacos.core.auth.admin.enabled=true` 开启了 admin API 认证，只支持 Token 认证，不支持 HTTP Basic Auth。Higress 的 Nacos Go Client 使用 Basic Auth。

**解决**：修改 Nacos 配置，关闭 admin API 认证
```bash
docker exec nacos-standalone bash -c "sed -i 's/nacos.core.auth.admin.enabled=true/nacos.core.auth.admin.enabled=false/' /home/nacos/conf/application.properties"
docker restart nacos-standalone
```

---

### 问题 3：Redis 连接失败

**现象**：Gateway 日志报错
```
error Redis connection check failed: dial tcp 172.17.0.3:6379: connect: connection refused
```

**原因**：Nacos 重启后，Redis 容器 IP 从 `172.17.0.3` 变为 `172.17.0.4`

**解决**：更新 Higress 配置中的 Redis 地址
```bash
docker exec higress bash -c "sed -i 's/172.17.0.3:6379/172.17.0.4:6379/' /data/configmaps/higress-config.yaml"
docker restart higress
```

---

### 问题 4：后端服务 503 连接超时

**现象**：MCP 工具调用报错
```
upstream connect error or disconnect/reset before headers. 
retried and the latest reset reason: connection timeout
```

**原因**：后端服务以 JAR 方式运行时，注册到 Nacos 的 IP 是容器内部 IP `172.20.10.2`，Higress 容器无法访问。

**解决**：将后端服务也以 Docker 容器方式运行，所有容器连接到同一个自定义网络 `mcp-net`，通过容器名互相访问。

---

### 问题 5：容器间网络不通

**现象**：容器无法通过容器名互相访问

**原因**：默认 `bridge` 网络不支持容器名 DNS 解析。Docker Compose 自动创建的独立网络也无法与其他容器的网络互通。

**解决**：创建自定义网络 `mcp-net`，将所有相关容器连接到此网络
```bash
docker network create mcp-net
docker network connect mcp-net nacos-standalone
docker network connect mcp-net higress
docker network connect mcp-net redis
docker network connect mcp-net mysql
```

---

## 一键部署命令

### 1. 创建网络
```bash
docker network create mcp-net
```

### 2. 启动所有依赖服务
```bash
docker compose -f docker-compose-infra.yml up -d
```

### 3. 启动后端服务
```bash
./start.sh
```

### 4. 验证
```bash
# 检查服务注册
curl -u nacos:nacos "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=nacos-mcp-demo"

# 验证 MCP SSE
timeout 5 curl -s http://localhost:8081/mcp/mcp-test/sse

# 测试后端服务
curl http://localhost:8082/api/users
```

---

## Higress McpBridge 配置要点

### Nacos 注册中心配置
```yaml
registries:
  - domain: nacos-standalone    # 使用容器名
    enableMCPServer: true       # 必须为 true
    mcpServerBaseUrl: /mcp
    nacosGroups:
      - DEFAULT_GROUP
    nacosNamespaceId: public
    name: nacos3
    port: 8848
    type: nacos3
    username: nacos
    password: nacos
```

### Redis 配置
```yaml
mcpServer:
  enable: true
  sse_path_suffix: /sse
  redis:
    address: redis:6379        # 使用容器名
    password: admin1234
    db: 0
```

---

## Higress 配置文件

### 1. McpBridge 配置

**文件路径**：`/data/mcpbridges/default.yaml`（容器内）

```yaml
apiVersion: networking.higress.io/v1
kind: McpBridge
metadata:
  name: default
  namespace: higress-system
spec:
  registries:
    # Higress 控制台（静态注册）
    - domain: 127.0.0.1:8001
      name: higress-console
      port: 80
      type: static
    # Nacos 注册中心
    - authSecretName: nacos3-auth-y2i2k    # 引用认证 Secret
      domain: nacos-standalone              # Nacos 容器名
      enableMCPServer: true                 # 必须为 true
      mcpServerBaseUrl: /mcp
      nacosGroups:
        - DEFAULT_GROUP
      nacosNamespaceId: public
      name: nacos3
      port: 8848
      type: nacos3
      username: nacos                       # 用户名（存储在 Secret 中）
      password: nacos                       # 密码（存储在 Secret 中）
```

### 2. 认证 Secret 配置

**文件路径**：`/data/secrets/nacos3-auth-y2i2k.yaml`（容器内）

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nacos3-auth-y2i2k
  namespace: higress-system
  labels:
    higress.io/resource-definer: higress
data:
  nacosUsername: bmFjb3M=    # base64 编码的 "nacos"
  nacosPassword: bmFjb3M=    # base64 编码的 "nacos"
```

> 注意：`nacosPassword` 和 `nacosUsername` 的值是 Base64 编码的。

### 3. Higress 全局配置

**文件路径**：`/data/configmaps/higress-config.yaml`（容器内）

```yaml
apiVersion: v1
data:
  higress: |
    mcpServer:
      enable: true
      sse_path_suffix: "/sse"
      redis:
        address: "redis:6379"        # Redis 容器名:端口
        username: ""
        password: "admin1234"
        db: 0
      match_list: []
      servers: []
```

### 配置说明

| 配置项 | 说明 | 注意事项 |
|--------|------|----------|
| `enableMCPServer` | 是否启用 MCP Server 功能 | **必须为 true**，否则无法拉取 MCP 配置 |
| `domain` | Nacos 服务地址 | 容器网络中使用容器名 `nacos-standalone` |
| `mcpServerBaseUrl` | MCP 服务基础路径 | 固定为 `/mcp` |
| `authSecretName` | 认证信息引用 | 指向 Secret 资源，存储 Nacos 用户名密码 |
| `sse_path_suffix` | SSE 端点后缀 | 固定为 `/sse` |
| `redis.address` | Redis 地址 | 容器网络中使用容器名 `redis` |

---

## Nacos MCP Server 配置

### 基本信息
| 字段 | 值 |
|------|-----|
| MCP 名称 | `mcp-test` |
| 描述 | 获取用户列表 |
| 版本 | `1.0.0` |

### 端点配置
| 字段 | 值 |
|------|-----|
| 端点类型 | `HTTP` |
| 服务引用 | 选择 `nacos-mcp-demo` 服务 |
| 导出路径 | `/mcp` |

### 工具配置
| 工具名 | 描述 | 请求模板 |
|--------|------|----------|
| `getAllUser` | 获取所有用户 | `GET /api/users` |
| `getUserById` | 根据 ID 获取用户 | `GET /api/users/{id}` |
| `getUserByName` | 根据名称获取用户 | `GET /api/users/name/{name}` |
| `createUser` | 创建用户 | `POST /api/users` |
| `updateUser` | 更新用户 | `PUT /api/users/{id}` |
| `deleteUser` | 删除用户 | `DELETE /api/users/{id}` |
| `getAllOrder` | 获取所有订单 | `GET /api/orders` |
| `getOrderById` | 根据 ID 获取订单 | `GET /api/orders/{id}` |
| `getOrdersByUserId` | 根据用户 ID 获取订单 | `GET /api/orders/user/{userId}` |
| `createOrder` | 创建订单 | `POST /api/orders` |
| `updateOrderStatus` | 更新订单状态 | `PATCH /api/orders/{id}/status` |
| `getJobPosition` | 查询员工岗位 | `GET /api/employee/position?name={name}` |
