# Nacos MCP Demo

Spring Boot 应用注册到 Nacos，通过 Higress MCP Bridge 暴露为 MCP Server，使用 SSE 协议对外提供服务，支持 AI Agent（如 Qwen Code）调用。

## 架构说明

### 逻辑架构

```
┌─────────────┐     注册服务      ┌──────────────┐
│  Spring Boot│ ────────────────> │   Nacos      │
│  (nacos-mcp │                   │  注册中心     │
│   -demo)    │ <──────────────── │              │
└─────────────┘   服务发现        └──────────────┘
                                          │
                                          │ 配置 MCP Server
                                          ▼
                                   ┌──────────────┐
                                   │   Higress    │
                                   │  MCP Bridge  │
                                   │  (SSE 网关)   │
                                   └──────────────┘
                                          │
                                          │ SSE 端点
                                          ▼
                                   ┌──────────────┐
                                   │  Qwen Code   │
                                   │  (AI Agent)  │
                                   └──────────────┘
```

### 网络拓扑架构

本项目把基础设施和应用都跑在同一条 Docker 自定义网络 **`mcp-net`** 上。容器之间用 **容器名做 DNS**（例如 `mysql`、`nacos-standalone`、`redis`），不要写会变的容器 IP。宿主机通过端口映射访问控制台、REST API 和 MCP SSE。

```
                              宿主机 (localhost)
  ┌────────┬────────┬────────┬────────┬────────┬────────┬────────┐
  │ 3306   │ 8848   │ 8080   │ 6379   │ 8001   │ 8081   │ 8082   │
  │        │ 9848   │        │        │        │ 8443   │        │
  └───┬────┴───┬────┴───┬────┴───┬────┴───┬────┴───┬────┴───┬────┘
      │        │        │        │        │        │        │
      │   Docker 端口映射（仅宿主机 ↔ 指定容器）
      │        │        │        │        │        │        │
┌─────▼────────▼────────▼────────▼────────▼────────▼────────▼─────┐
│                    Docker Network: mcp-net                       │
│                    （自定义 bridge，容器名可解析）                  │
│                                                                  │
│   ┌──────────┐   JDBC :3306    ┌─────────────────────────────┐  │
│   │  mysql   │◄───────────────│ nacos-mcp-demo               │  │
│   │  :3306   │                 │ 容器 8082 → 宿主机 8082      │  │
│   │ 库 app   │                 │ Nacos namespace: public      │  │
│   │ 库 nacos2│                 └──────────────▲──────────────┘  │
│   └────┬─────┘                                │                │
│        │  nacos2 持久化                        │ HTTP /api/*    │
│        ▼                                       │ （服务发现后转发）│
│   ┌────────────────┐  注册 / 发现 :8848/:9848  │                │
│   │ nacos-standalone│◄─────────────────────────┘                │
│   │ :8848 HTTP      │                                           │
│   │ :9848 gRPC      │  拉 MCP 配置 / 服务实例                    │
│   │ :8080 控制台     │────────────────────────────────┐          │
│   └────────────────┘                                 │          │
│                                                      ▼          │
│   ┌──────────┐  SSE 会话 :6379  ┌────────────────────────────┐ │
│   │  redis   │◄────────────────│ higress                     │ │
│   │  :6379   │                  │ 控制台 :8001 → 宿主机 8001   │ │
│   └──────────┘                  │ 网关   :8080 → 宿主机 8081   │ │
│                                 │ HTTPS  :8443 → 宿主机 8443   │ │
│                                 └──────────────▲───────────────┘ │
└─────────────────────────────────────────────────│────────────────┘
                                                  │
                           MCP SSE  http://localhost:8081/mcp/mcp-test/sse
                                                  │
                                     ┌────────────┴────────────┐
                                     │ Cursor / Qwen Code 等   │
                                     │ AI Agent（跑在宿主机）    │
                                     └─────────────────────────┘
```

#### 为什么必须用 `mcp-net`

默认 `bridge` 网络没有容器名 DNS。两个 Compose 文件各自建网时，基础设施和应用也互相解析不到。因此先执行 `docker network create mcp-net`，再让 `docker-compose-infra.yml` 与 `docker-compose.yml` 都声明 `external: true` 接入同一网络。后端若以宿主机 JAR 跑并注册容器不可达的 IP，Higress 转发会 503；应用也必须进 `mcp-net`。

#### 组件、容器名与端口

| 角色 | 容器名 | 网络内地址 | 宿主机映射 | 说明 |
|------|--------|------------|------------|------|
| 业务库 + Nacos 库 | `mysql` | `mysql:3306` | `3306` | `app` 给业务；`nacos2` 给 Nacos |
| 注册 / 配置 / MCP 定义 | `nacos-standalone` | `nacos-standalone:8848`（gRPC `9848`） | `8848` / `9848` / `8080` | 别名 `nacos-standalone-mysql`；控制台也可走 `8080` |
| MCP SSE 会话 | `redis` | `redis:6379` | `6379` | 密码 `admin1234`；Higress 必须用容器名，不能写会变的 IP |
| MCP / HTTP 网关 | `higress` | `higress:8080`、`:8001`、`:8443` | `8081` / `8001` / `8443` | 容器内网关是 **8080**，对外是 **8081** |
| Nacos MCP Router | `nacos-mcp-router` | `nacos-mcp-router:8000` | `8000` | Router 模式 streamableHTTP：`/mcp`、`/sse` |
| MCP Router Proxy（可选） | `nacos-mcp-router-proxy` | `:8000`（映射宿主机 **8002**） | `8002` | `PROXIED_MCP_NAME=mcp-test`，需 `--profile mcp-proxy` |
| 业务应用 | `nacos-mcp-demo` | `nacos-mcp-demo:8082` | `8082` | 注册到 Nacos namespace `public`；REST 与 MCP 工具调用均走此实例 |

Nacos 控制台默认 `nacos` / `nacos`。Higress McpBridge 里 `nacosNamespaceId: public`，与 `docker-compose.yml` 中的注册命名空间一致。

#### 三个平面

| 平面 | 路径 | 协议 / 端口 |
|------|------|-------------|
| **控制面** | 应用 → Nacos 注册实例；Higress → Nacos 拉 MCP Server 与实例列表 | HTTP `8848`，gRPC `9848` |
| **数据面** | Agent → Higress SSE → 转发到 Spring Boot 内置 MCP Server（SSE） | 宿主机 `8081`；网内 `higress:8080` → `nacos-mcp-demo:8082` |
| **存储面** | 应用 → MySQL `app`；Nacos → MySQL `nacos2`；Higress → Redis | `3306` / `6379` |

#### 一次 MCP 调用怎么走

1. Agent 连 `http://localhost:8081/mcp/mcp-test/sse`（映射到 Higress 容器 `8080`）。
2. Higress 用 Redis（`redis:6379`）建 SSE 会话，返回 `sessionId`。
3. Agent `tools/list` / `tools/call`；Higress 按 Nacos 中自动注册的 MCP Server `mcp-test` 转发到 `nacos-mcp-demo:8082` 的 MCP 端点。
4. Spring AI 执行对应 `@Tool` 方法，经 Service/MyBatis 访问 `mysql:3306/app`。
5. 结果原路经 Higress 回到 Agent。

旁路：浏览器/curl 可直连 `localhost:8082` 测 REST，不必经过 Higress。Nacos / Higress 控制台分别是 `localhost:8848/nacos/`（或 `8080`）和 `localhost:8001/`。

#### 容器内 vs 宿主机地址

| 调用方 | Nacos | MySQL | Redis | 业务 API | MCP SSE |
|--------|-------|-------|-------|----------|---------|
| 容器内（应用 / Higress） | `nacos-standalone:8848` | `mysql:3306` | `redis:6379` | `nacos-mcp-demo:8082` | `higress:8080` |
| 宿主机（脚本、Agent、浏览器） | `localhost:8848` | `localhost:3306` | `localhost:6379` | `localhost:8082` | `localhost:8081` |

`docker-compose.yml` 已用环境变量覆盖 `application.yml` 里的远程 IP。IDE 在宿主机直接跑应用时，要把数据源和 Nacos 改成 `localhost`；这样注册的是宿主机 IP，`mcp-net` 里的 Higress 通常访问不到，MCP 转发会失败。联调 MCP 请用 Compose 起应用容器。

#### Compose 与网络声明

- `docker-compose-infra.yml`：`mysql`、`nacos`、`redis`、`higress` → `mcp-net`
- `docker-compose.yml`：`nacos-mcp-demo` → 外部网络 `mcp-net`
- Higress 配置挂在宿主机 `/app/higress` → 容器 `/data`（McpBridge、Secret、`higress-config`）

### 工作流程

1. **服务注册**: Spring Boot 应用启动后自动注册到 Nacos
2. **MCP 自动注册**: 应用内 `@Tool` 定义的 16 个工具随启动写入 Nacos（[Spring AI Alibaba MCP Registry](https://nacos.io/docs/latest/manual/user/ai/mcp-auto-register/)）
3. **网关暴露**: Higress MCP Bridge 从 Nacos 拉取 MCP 配置，经 Redis 暴露 SSE 端点
4. **AI 调用**: Cursor / Qwen Code 等 Agent 通过 SSE 调用 MCP 工具
5. **（可选）Nacos MCP Router**: Agent 连接 Router，在 Nacos 中**搜索 / 安装 / 代理**多个 MCP Server，无需逐个配置端点

### Nacos MCP Router（智能路由）

[Nacos MCP Router](https://nacos.io/docs/next/manual/user/ai/nacos-mcp-router/) 是 **「MCP 的 MCP」**：向 Agent 提供在 Nacos Registry 中 **搜索、加载、代调** 其它 MCP（如本项目的 `mcp-test`）的能力，而不是直接暴露 16 个业务工具。

| 模式 | 说明 | 本仓库默认 |
|------|------|------------|
| **Router** | 元工具 `search_mcp_server` → `add_mcp_server` → `use_tool` | `nacos-mcp-router`，端口 **8000** |
| **Proxy** | 将 Registry 中某 MCP 转为 streamableHTTP，透明转发 | profile `mcp-proxy`，端口 **8002**，`mcp-test` |

**原理、时序图、Agent 分步示例、与直连 Higress 的对比** → 详见 **[NACOS-MCP-ROUTER.md](./NACOS-MCP-ROUTER.md)**。

**快速启动**（基础设施已 `up` 且 `mcp-test` 已注册）：

```bash
./scripts/setup-nacos-mcp-router.sh
ENABLE_MCP_ROUTER_PROXY=true ./scripts/setup-nacos-mcp-router.sh   # 可选 Proxy
```

**Cursor 配置**（更多见 `scripts/mcp-client-nacos-router.json`）：

```json
{
  "mcpServers": {
    "nacos-mcp-router": {
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

典型 Router 模式链路：用户问「有哪些订单？」→ `search_mcp_server` → `add_mcp_server("mcp-test")` → `use_tool(..., "getAllOrders", {})`。

## 技术栈

- Spring Boot 3.4.5
- Spring AI 1.1.0 + Spring AI Alibaba MCP Registry
- Spring Cloud Alibaba 2023.0.3.2
- Nacos 3.1.2
- Higress Gateway
- MySQL 8.0（业务数据存储）
- MyBatis（数据库访问）
- Flyway（数据库结构版本化迁移）

---

## 完整配置流程

### 方式 A：命令行一键（推荐）

```bash
# 1. 创建 Docker 网络（仅首次）
docker network create mcp-net 2>/dev/null || true

# 2. 基础设施：MySQL / Nacos / Redis / Higress
docker compose -f docker-compose-infra.yml up -d

# 3. 构建并启动 Spring Boot 服务（8082）
./build.sh

# 4. 配置 Higress MCP Bridge（MCP Server 由应用在步骤 3 启动时自动注册到 Nacos）
./scripts/setup-mcp-higress.sh

# 5. （可选）启动 Nacos MCP Router，供 Agent 搜索/代理 Nacos 中的 MCP
./scripts/setup-nacos-mcp-router.sh
```

MySQL 首次启动会通过 `src/main/resources/db/docker/` 自动创建 **`app`** 业务库与 **`nacos2`** 库表。应用启动时 **Flyway** 执行建表与演示数据，并向 Nacos 注册服务实例与 MCP Server（`mcp-test`）。

### 方式 B：分步说明

#### 步骤一：启动依赖服务

```bash
docker network create mcp-net 2>/dev/null || true
docker compose -f docker-compose-infra.yml up -d
docker compose -f docker-compose-infra.yml ps
```

| 服务 | 地址 |
|------|------|
| Nacos 控制台 | http://localhost:8848/nacos/ 或 http://localhost:8080 |
| Higress 控制台 | http://localhost:8001/ |
| MySQL | `localhost:3306`（root / root） |
| Redis | `localhost:6379`（密码 `admin1234`） |

Nacos 控制台默认账号 **`nacos` / `nacos`**。若无法登录，参见 [常见问题](#6-nacos-控制台无法登录)。

#### 步骤二：构建并启动本服务

```bash
./build.sh
```

本地未安装 JDK/Maven 时，可用 Docker 打包后再构建镜像：

```bash
docker run --rm -v "$PWD":/app -w /app maven:3.9-eclipse-temurin-17 \
  mvn clean package -DskipTests
docker compose build && docker compose up -d
```

#### 步骤三～四：Higress MCP Bridge

**脚本（推荐）**：

```bash
./scripts/setup-mcp-higress.sh
```

脚本会：清理旧的 OpenAPI/HTTP 代理式 MCP 定义（若存在）、写入 Higress McpBridge 与 Redis 配置并重启 Higress。**MCP Server 与 16 个工具无需再手动或脚本导入**，由 `nacos-mcp-demo` 启动时自动注册。

**控制台（可选）**：在 Nacos **AI 管理 → MCP Server** 可查看自动注册的 `mcp-test`；Higress 可在 http://localhost:8001/ 的 **MCP Bridge** 中手动添加 Nacos（`nacos-standalone:8848`，`enableMCPServer: true`）。排查细节见 [HIGRESS_DEPLOYMENT_GUIDE.md](./HIGRESS_DEPLOYMENT_GUIDE.md)。

#### 步骤五：验证 SSE 端点

SSE 为长连接，请加超时：

```bash
curl --max-time 3 -s http://localhost:8081/mcp/mcp-test/sse
```

正常响应：

```
event: endpoint
data: /mcp/mcp-test?sessionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Higress 刚重启后若返回 404，等待约 10～20 秒再试，或重新执行 `./scripts/setup-mcp-higress.sh`。

### 步骤六：使用 Qwen Code 调用 MCP 服务

#### 方式一：使用 Qwen Code MCP 配置

在 Qwen Code 中配置 MCP 服务器：

1. 打开 Qwen Code 设置
2. 添加 MCP Server：
   - 名称：`mcp-test`
   - URL：`http://localhost:8081/mcp/mcp-test/sse`
   - 类型：`SSE`

3. 保存后，Qwen Code 会自动发现可用的 16 个工具

#### 方式二：直接调用示例

**用户提问**: "帮我查一下有哪些订单？"

**Qwen Code 会自动**:
1. 连接到 SSE 端点
2. 获取工具列表（`tools/list`）
3. 选择合适的工具（`getAllOrders`）
4. 调用工具并获取结果
5. 将结果格式化后回复给用户

#### 调用示例

```
用户: 张三都买了什么？

Qwen Code 执行流程:
1. 调用 getUserByName({"name": "张三"}) → 获取用户ID: user-1
2. 调用 getOrdersByUserId({"userId": "user-1"}) → 获取订单列表
3. 整理结果回复用户

回复:
张三（user-1）有 2 个订单：
1. iPhone 15 Pro - 7999元（已完成）
2. AirPods Pro - 1899元 x 2（待处理）
```

### 可用的 MCP 工具

Qwen Code 可以调用以下 16 个工具：

| 分类 | 工具 | 说明 |
|------|------|------|
| 订单管理 | getAllOrders | 获取所有订单 |
| 订单管理 | getOrderById | 根据ID获取订单 |
| 订单管理 | getOrdersByUserId | 根据用户ID获取订单 |
| 订单管理 | createOrder | 创建订单 |
| 订单管理 | updateOrderStatus | 更新订单状态 |
| 用户管理 | getAllUsers | 获取所有用户 |
| 用户管理 | getUserById | 根据ID获取用户 |
| 用户管理 | getUserByName | 根据姓名搜索用户 |
| 用户管理 | createUser | 创建用户 |
| 用户管理 | updateUser | 更新用户 |
| 用户管理 | deleteUser | 删除用户 |
| 员工管理 | getJobPosition | 查询员工岗位 |
| 员工管理 | getAllEmployees | 获取所有员工 |
| 员工管理 | createEmployee | 创建员工 |
| 员工管理 | updateEmployeePosition | 更新员工岗位 |
| 员工管理 | deleteEmployee | 删除员工 |

---

## 快速开始

### 1. 前置条件

- **Docker** 与 **Docker Compose**（`docker compose` 子命令）
- **JDK 17+ / Maven 3.8+**（可选；亦可用 Maven 官方 Docker 镜像打包）

### 2. 构建和部署

与 [方式 A：命令行一键](#方式-a命令行一键推荐) 相同：`mcp-net` → `docker-compose-infra.yml` → `./build.sh` → `./scripts/setup-mcp-higress.sh`。

`build.sh` 使用 **`docker compose`**（非 `docker-compose`），启动单个应用容器：

| 容器 | 端口 | Nacos 命名空间 |
|------|------|----------------|
| `nacos-mcp-demo` | 8082 | `public` |

分步命令：

```bash
./build.sh package    # 仅 Maven 打包
./build.sh build      # 打包 + 构建镜像
./build.sh up         # 启动应用容器
./build.sh down       # 停止应用容器
```

### 3. 验证服务

```bash
# REST API
curl http://localhost:8082/api/users
curl http://localhost:8082/api/orders
curl "http://localhost:8082/api/employee/position?name=%E5%BC%A0%E4%BC%9F"

# Nacos 注册（public 命名空间下服务名均为 nacos-mcp-demo）
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=nacos-mcp-demo"

# MCP SSE
curl --max-time 3 -s http://localhost:8081/mcp/mcp-test/sse
```

---

## Agent 对话演示（Deep Agents + MCP）

在 Higress SSE 之上增加 **LangGraph Deep Agent** 与 **Web 对话界面**，通过自然语言调用已注册的 16 个 MCP 工具（用户 / 订单 / 员工）。技术栈：[Deep Agents](https://docs.langchain.com/oss/python/deepagents/overview)、`MCPAdapter`（SSE）、前端 [`useStream`](https://docs.langchain.com/oss/python/deepagents/frontend/todo-list)。

### 前置条件

- 已完成 [方式 A：命令行一键](#方式-a命令行一键推荐)（`mcp-net`、Higress、`nacos-mcp-demo`、MCP SSE 可访问）
- 安装 [uv](https://docs.astral.sh/uv/)（Python Agent）与 **Node.js 18+**（前端）
- 复制环境变量：`cp .env.example .env`，填写 **硅基流动** `SILICONFLOW_API_KEY`（OpenAI 兼容接口）

### 启动步骤

**终端 1 — LangGraph Agent（端口 2024）**

```bash
cd agent
uv sync --dev
uv run langgraph dev
```

启动日志中应看到 MCP 已加载约 **16** 个工具（经 `http://localhost:8081/mcp/mcp-test/sse`）。

**终端 2 — 对话 UI（端口 5173）**

```bash
cd frontend
npm install
npm run dev
```

浏览器打开 http://localhost:5173 ，或使用界面上的快捷问句。

也可使用一键脚本（检查 SSE 后提示上述命令）：

```bash
chmod +x ./scripts/start-agent-demo.sh
./scripts/start-agent-demo.sh          # 仅检查 + 说明
./scripts/start-agent-demo.sh agent    # 前台启动 LangGraph
./scripts/start-agent-demo.sh docker   # docker compose -f docker-compose-agent.yml
```

### 演示问句

| 用户输入 | 预期 MCP 行为 |
|----------|----------------|
| 帮我查一下目前有哪些订单？ | `getAllOrders` |
| 张三都买了什么？ | `getUserByName` → `getOrdersByUserId` |
| 张伟是什么岗位？ | `getJobPosition` |

复杂任务时 UI 顶部会显示 **Agent 进度**（`TodoListMiddleware`）；每条助手回复下方展示 **工具调用卡片**（工具名、参数、返回摘要）。

### 环境变量（摘要）

见 [.env.example](.env.example)：`SILICONFLOW_*`、`MCP_SSE_URL`、`VITE_AGENT_URL`。Agent 跑在 Docker 网络内时请将 `MCP_SSE_URL` 设为 `http://higress:8080/mcp/mcp-test/sse`。

### 子项目说明

| 目录 | 说明 |
|------|------|
| [agent/](agent/) | `create_deep_agent` + Higress SSE MCP + `langgraph dev` |
| [frontend/](frontend/) | React + `@langchain/react` 流式对话 |

---

## 数据库配置

### MySQL 容器

MySQL 运行在 Docker 容器中，自动持久化数据：

```bash
# MySQL 连接信息
主机：localhost
端口：3306
用户名：root
密码：root
数据库：app
```

### 数据表

| 表名 | 说明 | 初始数据 |
|------|------|---------|
| `users` | 用户表 | 3 条 |
| `orders` | 订单表 | 3 条 |
| `employees` | 员工表 | 114 条 |

### 数据库迁移（Flyway）

| 路径 | 说明 |
|------|------|
| `src/main/resources/db/migration/` | 结构迁移（`V1__` 起，只增不改） |
| `src/main/resources/db/migration-seed/` | 演示种子数据（默认随应用启动导入） |
| `src/main/resources/db/docker/` | MySQL 容器 **首次** 启动：`app` 库、`nacos2`  schema |
| `src/main/resources/db/create-app-database.sql` | 手动补建 `app` 库（非全新数据卷时） |

**默认行为**：应用启动时 Flyway 连接 `app` 库，依次执行 `V1__baseline_schema.sql`、`V2__seed_demo_data.sql`，并在库中维护 `flyway_schema_history` 表。

**生产环境**（只要表结构、不要演示数据）：

```bash
export SPRING_PROFILES_ACTIVE=prod
# 或 Docker：SPRING_PROFILES_ACTIVE=prod
```

`application-prod.yml` 仅加载 `classpath:db/migration`，跳过 `migration-seed`。

**表结构变更流程**：

1. 新增脚本，例如 `src/main/resources/db/migration/V3__orders_add_remark.sql`
2. 提交代码；各环境下次启动应用时自动执行新脚本
3. 已发布过的迁移脚本**不要修改内容**；纠错请再写更高版本号的脚本

**重新初始化业务库**（清空数据并从头迁移）：

```bash
docker exec -i mysql mysql -uroot -proot -e "DROP DATABASE IF EXISTS app;"
docker exec -i mysql mysql -uroot -proot < src/main/resources/db/create-app-database.sql
# 重启应用容器，Flyway 会重新执行 V1、V2
docker compose restart nacos-mcp-demo
```

**从旧版手工 `init.sql` 升级**：若 `app` 库中已有表但没有 `flyway_schema_history`，请先按上面步骤删库重建，避免 Flyway 与手工建表冲突。

---

## Nacos MCP 自动注册

应用使用 **Spring AI Alibaba MCP Registry**，启动后将 MCP Server `mcp-test` 与全部工具注册到 Nacos。配置见 `src/main/resources/application.yml` 中的 `spring.ai.mcp.server` 与 `spring.ai.alibaba.mcp.nacos`。

- 环境变量：`NACOS_SERVER_ADDR`、`NACOS_USERNAME`、`NACOS_PASSWORD`、`MCP_SERVER_NAME`（默认 `mcp-test`）
- 工具定义：`src/main/java/com/example/mcp/tools/`（`@Tool` / `@ToolParam`）
- 若曾用 OpenAPI 脚本注册过同名 MCP，首次迁移时 `setup-mcp-higress.sh` 会尝试删除旧定义，避免 `mcp server info is not compatible` 启动失败

在 Nacos 控制台 **AI 管理 → MCP Server** 可查看、热更新工具描述或启停工具，无需重启应用。

---

## API 接口文档

### 用户管理（/api/users）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/users` | 获取所有用户 |
| GET | `/api/users/{id}` | 根据 ID 获取用户 |
| GET | `/api/users/name/{name}` | 根据姓名搜索用户 |
| POST | `/api/users` | 创建用户 |
| PUT | `/api/users/{id}` | 更新用户 |
| DELETE | `/api/users/{id}` | 删除用户 |

### 订单管理（/api/orders）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/orders` | 获取所有订单 |
| GET | `/api/orders/{id}` | 根据 ID 获取订单 |
| GET | `/api/orders/user/{userId}` | 根据用户 ID 获取订单 |
| POST | `/api/orders` | 创建订单 |
| PATCH | `/api/orders/{id}/status` | 更新订单状态 |

### 员工管理（/api/employee）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/employee/position?name=xxx` | 根据姓名查询员工岗位 |
| GET | `/api/employee/list` | 获取所有员工 |
| POST | `/api/employee` | 创建员工 |
| PATCH | `/api/employee/position` | 更新员工岗位 |
| DELETE | `/api/employee/{id}` | 删除员工 |

---

## MCP 工具配置

新增或修改 MCP 工具：在 `src/main/java/com/example/mcp/tools/` 增加 `@Tool` 方法（可复用现有 Service），重启 `nacos-mcp-demo` 后自动同步到 Nacos。REST API 仍保留在 Controller 层；`openapi-spec.json` 仅作文档/对照，不再用于注册。

### 工具列表（共 16 个）

| 工具名 | 描述 | 分类 |
|--------|------|------|
| `getAllUsers` | 获取所有用户 | 用户管理 |
| `getUserById` | 根据 ID 获取用户 | 用户管理 |
| `getUserByName` | 根据姓名搜索用户 | 用户管理 |
| `createUser` | 创建用户 | 用户管理 |
| `updateUser` | 更新用户 | 用户管理 |
| `deleteUser` | 删除用户 | 用户管理 |
| `getAllOrders` | 获取所有订单 | 订单管理 |
| `getOrderById` | 根据 ID 获取订单 | 订单管理 |
| `getOrdersByUserId` | 根据用户 ID 获取订单 | 订单管理 |
| `createOrder` | 创建订单 | 订单管理 |
| `updateOrderStatus` | 更新订单状态 | 订单管理 |
| `getJobPosition` | 查询员工岗位 | 员工管理 |
| `getAllEmployees` | 获取所有员工 | 员工管理 |
| `createEmployee` | 创建员工 | 员工管理 |
| `updateEmployeePosition` | 更新员工岗位 | 员工管理 |
| `deleteEmployee` | 删除员工 | 员工管理 |

---

## MCP 工具调用示例

详细的 AI Agent 调用示例请参考 [MCP-USAGE-EXAMPLES.md](./MCP-USAGE-EXAMPLES.md) 文档。

### 快速示例

#### 查询订单
**用户**: "帮我查一下 ORDER-001 的状态"
**AI 调用**: `getOrderById({"id": "ORDER-001"})`

#### 查询员工岗位
**用户**: "张伟是什么岗位？"
**AI 调用**: `getJobPosition({"name": "张伟"})`

#### 创建用户
**用户**: "添加用户赵六，邮箱 zhaoliu@example.com"
**AI 调用**: `createUser({"name": "赵六", "email": "zhaoliu@example.com"})`

---

## API 测试示例

### 用户管理

```bash
# 获取所有用户
curl http://localhost:8082/api/users

# 根据 ID 获取用户
curl http://localhost:8082/api/users/user-1

# 创建用户
curl -X POST http://localhost:8082/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"测试用户","email":"test@example.com"}'
```

### 订单管理

```bash
# 获取所有订单
curl http://localhost:8082/api/orders

# 创建订单
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-1","product":"iPad Pro","quantity":1,"price":6999}'

# 更新订单状态
curl -X PATCH http://localhost:8082/api/orders/ORDER-001/status \
  -H "Content-Type: application/json" \
  -d '{"status":"completed"}'
```

### 员工管理

```bash
# 查询员工岗位（中文需要 URL 编码）
curl "http://localhost:8082/api/employee/position?name=%E5%BC%A0%E4%BC%9F"

# 获取所有员工
curl http://localhost:8082/api/employee/list

# 创建员工
curl -X POST http://localhost:8082/api/employee \
  -H "Content-Type: application/json" \
  -d '{"name":"新员工","position":"后端开发"}'
```

---

## 配置说明

### Docker 环境变量（`docker-compose.yml`）

容器内通过环境变量覆盖 `application.yml` 中的地址，例如：

- `SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/app?...`
- `SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR=nacos-standalone:8848`

本地 IDE 直连时，请将数据源与 Nacos 地址改为 `localhost` 或你的宿主机 IP。

### application.yml

仓库内默认配置面向某远程 IP；**Docker 部署以 `docker-compose.yml` 环境变量为准**。本地运行可参考：

```yaml
server:
  port: 8082

spring:
  application:
    name: nacos-mcp-demo
  datasource:
    url: jdbc:mysql://localhost:3306/app?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
    username: root
    password: root
  cloud:
    nacos:
      discovery:
        server-addr: nacos-standalone:8848   # Docker 网络内
        username: nacos
        password: nacos
        namespace: public
        group: DEFAULT_GROUP
```

---

## 项目结构

```
nacos-mcp-demo/
├── agent/                              # Deep Agent（LangGraph + MCP SSE）
├── frontend/                           # 对话 UI（useStream）
├── build.sh                            # Maven 打包 + docker compose 构建/启动
├── scripts/
│   ├── setup-mcp-higress.sh            # Higress MCP Bridge 一键配置
│   ├── setup-nacos-mcp-router.sh       # Nacos MCP Router 启动与校验
│   ├── start-agent-demo.sh             # Agent 对话演示环境检查与启动提示
│   ├── mcp-client-nacos-router.json    # Cursor 等 MCP 客户端配置示例
│   ├── openapi_to_nacos_tools.py       # （遗留）OpenAPI → Nacos toolSpecification
│   ├── higress-mcpbridge-default.yaml  # Higress McpBridge 模板
│   └── higress-nacos-secret.yaml       # Nacos 认证 Secret 模板
├── Dockerfile                          # Docker 镜像构建
├── docker-compose.yml                  # 应用服务（8082）
├── docker-compose-infra.yml            # MySQL / Nacos / Redis / Higress
├── HIGRESS_DEPLOYMENT_GUIDE.md         # Higress MCP 排障与配置说明
├── NACOS-MCP-ROUTER.md                 # MCP Router 原理与 Agent 使用指南
├── openapi-spec.json                   # REST API OpenAPI 文档
├── MCP-USAGE-EXAMPLES.md               # MCP 工具调用示例
├── README.md                           # 本文档
└── src/main/
    ├── java/com/example/mcp/
    │   ├── NacosMcpDemoApplication.java       # 启动类
    │   ├── config/
    │   │   └── McpServerConfiguration.java    # MCP ToolCallbackProvider
    │   ├── tools/                             # @Tool MCP 工具（自动注册到 Nacos）
    │   ├── controller/
    │   │   ├── UserController.java            # 用户管理 API
    │   │   ├── OrderController.java           # 订单管理 API
    │   │   └── EmployeeController.java        # 员工管理 API
    │   ├── service/
    │   │   ├── UserService.java               # 用户服务接口
    │   │   ├── OrderService.java              # 订单服务接口
    │   │   ├── EmployeeService.java           # 员工服务接口
    │   │   └── impl/                          # 服务实现
    │   ├── mapper/                            # MyBatis Mapper 接口
    │   └── entity/                            # 实体类
    └── resources/
        ├── application.yml                    # 应用配置
        ├── db/
        │   ├── create-app-database.sql        # 创建 app 库
        │   ├── docker/                        # MySQL 首次启动时建库
        │   ├── migration/                     # Flyway 结构迁移
        │   └── migration-seed/                # Flyway 演示种子数据
        └── mapper/                            # MyBatis XML 映射文件
```

---

## 常见问题

### 1. 数据库连接失败

检查 MySQL 容器是否正常运行：

```bash
docker ps | grep mysql
```

确保 `root` 用户有 `app` 数据库访问权限：

```bash
docker exec -i mysql mysql -uroot -proot -e "USE app; SHOW TABLES;"
```

### 2. 服务未注册到 Nacos

```bash
docker logs nacos-mcp-demo --tail 50
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=nacos-mcp-demo"
```

确认应用与 Nacos 在同一 Docker 网络 **`mcp-net`**，且 Nacos 地址为容器名 **`nacos-standalone:8848`**。

### 3. MCP SSE 返回 404

1. 确认 `./scripts/setup-mcp-higress.sh` 已执行，且 `docker exec higress wc -c /data/mcpbridges/default.yaml` 非 0。
2. Higress 重启后等待片刻再访问 `http://localhost:8081/mcp/mcp-test/sse`。
3. 详见 [HIGRESS_DEPLOYMENT_GUIDE.md](./HIGRESS_DEPLOYMENT_GUIDE.md)。

### 4. 中文参数问题

URL 中的中文参数需要进行 URL 编码：

```bash
# 错误（中文未编码）
curl "http://localhost:8082/api/employee/position?name=张伟"

# 正确（URL 编码）
curl "http://localhost:8082/api/employee/position?name=%E5%BC%A0%E4%BC%9F"
```

### 5. 重新初始化数据库

参见上文 [数据库迁移（Flyway）](#数据库迁移flyway) 中的「重新初始化业务库」。

### 6. Nacos 控制台无法登录

Nacos 3.x 需在库表 `nacos2.users` 中存在用户。可创建管理员 **`nacos` / `nacos`**：

```bash
HASH=$(docker run --rm python:3.12-slim sh -c \
  "pip -q install bcrypt && python -c \"import bcrypt; print(bcrypt.hashpw(b'nacos', bcrypt.gensalt(rounds=10, prefix=b'2a')).decode())\"")
docker exec mysql mysql -uroot -proot nacos2 -e "
INSERT INTO users (username, password, enabled) VALUES ('nacos', '${HASH}', 1)
  ON DUPLICATE KEY UPDATE password='${HASH}', enabled=1;
INSERT IGNORE INTO roles (username, role) VALUES ('nacos', 'ROLE_ADMIN');
INSERT IGNORE INTO permissions (role, resource, action) VALUES ('ROLE_ADMIN', '*:*:*', 'rw');
"
```

### 7. 查看服务日志

```bash
docker logs -f nacos-mcp-demo
docker logs -f higress --tail 100
docker logs -f nacos-standalone --tail 100
```
