# Nacos MCP Demo

Spring Boot 应用注册到 Nacos，通过 Higress MCP Bridge 暴露为 MCP Server，使用 SSE 协议对外提供服务，支持 AI Agent（如 Qwen Code）调用。

## 架构说明

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

### 工作流程

1. **服务注册**: Spring Boot 应用启动后自动注册到 Nacos
2. **MCP 配置**: 在 Nacos 控制台创建 MCP Server，配置工具列表
3. **网关暴露**: Higress 从 Nacos 读取 MCP 配置，暴露 SSE 端点
4. **AI 调用**: Qwen Code 通过 SSE 端点调用 MCP 工具

## 技术栈

- Spring Boot 3.2.0
- Spring Cloud Alibaba 2023.0.0.0-RC1
- Nacos 3.1.2
- Higress Gateway
- MySQL 8.0（业务数据存储）
- MyBatis（数据库访问）
- Flyway（数据库结构版本化迁移）

---

## 完整配置流程

### 步骤一：启动依赖服务

启动 MySQL、Nacos、Redis 和 Higress：

```bash
docker compose -f docker-compose-infra.yml up -d
```

等待所有服务启动（约 1-2 分钟）：

```bash
docker compose -f docker-compose-infra.yml ps
```

创建业务库 `app`（全新 MySQL 数据卷会在容器首次启动时自动创建；若库已存在可跳过）：

```bash
docker exec -i mysql mysql -uroot -proot < src/main/resources/db/create-app-database.sql
```

### 步骤二：构建并启动本服务

```bash
./build.sh
```

服务启动时会通过 **Flyway** 自动执行未应用的数据库迁移（建表 + 演示种子数据），并注册到 Nacos。

### 步骤三：在 Nacos 配置 MCP Server

1. 访问 Nacos 控制台：http://localhost:8848/nacos/
2. 进入 **AI 管理** → **MCP Server** → 点击 **新增**
3. 配置基本信息：

| 字段 | 值 |
|------|-----|
| MCP 名称 | `mcp-test` |
| 描述 | 用户管理、订单管理、员工岗位查询 |
| 版本 | `1.0.0` |

4. 配置端点：

| 字段 | 值 |
|------|-----|
| 端点类型 | `HTTP` |
| 服务引用 | 选择 `nacos-mcp-demo` |
| 导出路径 | `/mcp` |

5. 导入工具配置：
   - 选择"从 OpenAPI 文件导入"
   - 上传 `openapi-spec.json` 文件
   - 确认导入 16 个工具

6. 保存并发布

### 步骤四：配置 Higress MCP Bridge

通过 Higress 控制台配置 MCP Bridge：

1. 访问 Higress 控制台：http://localhost:8001/
2. 进入 **MCP Bridge** 配置
3. 添加 Nacos 数据源：
   - 地址：`http://nacos-standalone:8848`
   - 用户名：`nacos`
   - 密码：`nacos`
4. 保存配置

Higress 会自动从 Nacos 读取 MCP Server 配置并暴露 SSE 端点。

### 步骤五：验证 SSE 端点

```bash
timeout 5 curl -s http://localhost:8081/mcp/mcp-test/sse
```

正常响应：
```
event: endpoint
data: /mcp/mcp-test?sessionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

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

- JDK 17+
- Maven 3.8+
- Docker & Docker Compose
- MySQL 8.0（容器运行）

### 2. 构建和部署

#### 方式一：一键构建（推荐）

```bash
./build.sh
```

自动完成：Maven 打包 → Docker 构建镜像 → 容器重启

#### 方式二：分步构建

```bash
# 仅 Maven 打包
./build.sh package

# 打包 + 构建 Docker 镜像
./build.sh build

# 仅重启容器
./build.sh restart
```

#### 方式三：手动部署

```bash
# Maven 打包
mvn clean package -DskipTests

# 构建 Docker 镜像
docker-compose build

# 启动/重启容器
docker-compose down && docker-compose up -d
```

### 3. 验证服务

```bash
# 检查服务是否正常运行
curl http://localhost:8082/api/users
curl http://localhost:8082/api/orders
curl "http://localhost:8082/api/employee/position?name=%E5%BC%A0%E4%BC%9F"

# 检查服务是否注册到 Nacos
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=nacos-mcp-demo"
```

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
| `src/main/resources/db/create-app-database.sql` | 仅创建 `app` 库（迁移前执行一次） |

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
# 重启 nacos-mcp-demo 应用，Flyway 会重新执行 V1、V2
```

**从旧版手工 `init.sql` 升级**：若 `app` 库中已有表但没有 `flyway_schema_history`，请先按上面步骤删库重建，避免 Flyway 与手工建表冲突。

---

## Nacos 控制台配置 MCP Server

服务注册到 Nacos 后，需要在 Nacos 控制台配置 MCP Server。

### 访问 Nacos

- 地址：http://localhost:8848/nacos/
- 用户名：`nacos`
- 密码：`nacos`

### 新增 MCP Server

进入 **AI 管理** → **MCP Server** → 点击 **新增**

#### 基本信息

| 字段 | 值 |
|------|-----|
| MCP 名称 | `mcp-test` |
| 描述 | 用户管理、订单管理、员工岗位查询 |
| 版本 | `1.0.0` |

#### 端点配置

| 字段 | 值 |
|------|-----|
| 端点类型 | `HTTP` |
| 服务引用 | 选择 `nacos-mcp-demo` 服务 |
| 导出路径 | `/mcp` |

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

### 通过 OpenAPI 文件导入

在 Nacos 控制台可以使用 `openapi-spec.json` 文件批量导入工具配置：

1. 进入 MCP Server 编辑页面
2. 选择"从 OpenAPI 文件导入"
3. 上传 `openapi-spec.json` 文件
4. 确认导入

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

### application.yml

```yaml
server:
  port: 8082

spring:
  application:
    name: nacos-mcp-demo
  datasource:
    url: jdbc:mysql://localhost:3306/app?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: root
    driver-class-name: com.mysql.cj.jdbc.Driver
  cloud:
    nacos:
      discovery:
        server-addr: http://nacos-standalone:8848
        username: nacos
        password: nacos
        namespace: public
        group: DEFAULT_GROUP
        register-enabled: true

mybatis:
  mapper-locations: classpath:mapper/*.xml
  type-aliases-package: com.example.mcp.entity
  configuration:
    map-underscore-to-camel-case: true
```

---

## 项目结构

```
nacos-mcp-demo/
├── build.sh                            # 构建和部署脚本
├── Dockerfile                          # Docker 镜像构建
├── docker-compose.yml                  # 本服务 Docker Compose 配置
├── docker-compose-infra.yml            # 依赖服务（MySQL/Nacos/Redis/Higress）
├── .env                                # 环境变量
├── pom.xml                             # Maven 依赖
├── openapi-spec.json                   # OpenAPI 规范文件（用于 MCP 工具导入）
├── MCP-USAGE-EXAMPLES.md               # MCP 工具调用示例文档
├── README.md                           # 本文档
└── src/main/
    ├── java/com/example/mcp/
    │   ├── NacosMcpDemoApplication.java       # 启动类
    │   ├── config/
    │   │   └── NacosMcpRegistrar.java         # Nacos 元数据注册
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

检查 Nacos 连接：

```bash
docker logs nacos-mcp-demo | grep nacos
```

确保 Nacos 服务可访问：

```bash
curl http://localhost:8848/nacos/
```

### 3. 中文参数问题

URL 中的中文参数需要进行 URL 编码：

```bash
# 错误（中文未编码）
curl "http://localhost:8082/api/employee/position?name=张伟"

# 正确（URL 编码）
curl "http://localhost:8082/api/employee/position?name=%E5%BC%A0%E4%BC%9F"
```

### 4. 重新初始化数据库

参见上文 [数据库迁移（Flyway）](#数据库迁移flyway) 中的「重新初始化业务库」。

### 5. 查看服务日志

```bash
# 实时查看日志
docker logs -f nacos-mcp-demo

# 查看最近 100 行日志
docker logs nacos-mcp-demo --tail 100
```
