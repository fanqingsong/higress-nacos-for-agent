# MCP 工具调用示例

本文档提供 AI Agent 调用 MCP 工具的完整示例，包含用户提问、AI 调用方式和 AI 回复。

若 Agent 通过 **Nacos MCP Router** 接入（而非直连 Higress SSE），业务工具需经 Router 的 `use_tool("mcp-test", "<工具名>", params)` 调用；接入方式与原理见 **[NACOS-MCP-ROUTER.md](./NACOS-MCP-ROUTER.md)**。

---

## 📦 订单管理

### 1. getAllOrders - 获取所有订单

**用户提问**: "帮我查一下目前有哪些订单？"

**AI 调用**:
```json
{
  "tool": "getAllOrders",
  "arguments": {}
}
```

**AI 回复**:
> 目前有 3 个订单：
> - ORDER-001：iPhone 15 Pro，7999元，已完成
> - ORDER-002：MacBook Pro 14，14999元，已发货
> - ORDER-003：AirPods Pro，1899元 x 2，待处理

---

### 2. getOrderById - 根据ID获取订单

**用户提问**: "帮我看看订单 ORDER-001 的状态"

**AI 调用**:
```json
{
  "tool": "getOrderById",
  "arguments": {
    "id": "ORDER-001"
  }
}
```

**AI 回复**:
> 订单 ORDER-001 的详情：
> - 产品：iPhone 15 Pro
> - 数量：1
> - 价格：7999元
> - 状态：已完成
> - 下单时间：2024-01-15 10:30:00

---

### 3. getOrdersByUserId - 根据用户ID获取订单

**用户提问**: "用户 user-1 都买了什么？"

**AI 调用**:
```json
{
  "tool": "getOrdersByUserId",
  "arguments": {
    "userId": "user-1"
  }
}
```

**AI 回复**:
> 用户 user-1 有 2 个订单：
> 1. iPhone 15 Pro - 7999元（已完成）
> 2. AirPods Pro - 1899元 x 2（待处理）

---

### 4. createOrder - 创建订单

**用户提问**: "帮用户 user-2 创建一个订单，买一台 iPad Pro，价格 8999 元"

**AI 调用**:
```json
{
  "tool": "createOrder",
  "arguments": {
    "userId": "user-2",
    "product": "iPad Pro",
    "quantity": 1,
    "price": 8999
  }
}
```

**AI 回复**:
> ✅ 订单创建成功！
> - 订单号：ORDER-004
> - 产品：iPad Pro
> - 价格：8999元
> - 状态：待处理

---

### 5. updateOrderStatus - 更新订单状态

**用户提问**: "把订单 ORDER-003 的状态改为已发货"

**AI 调用**:
```json
{
  "tool": "updateOrderStatus",
  "arguments": {
    "id": "ORDER-003",
    "status": "shipped"
  }
}
```

**AI 回复**:
> ✅ 订单 ORDER-003 状态已更新为：已发货

---

## 👤 用户管理

### 6. getAllUsers - 获取所有用户

**用户提问**: "系统里有哪些注册用户？"

**AI 调用**:
```json
{
  "tool": "getAllUsers",
  "arguments": {}
}
```

**AI 回复**:
> 目前有 3 个注册用户：
> - user-1：张三（zhangsan@example.com）
> - user-2：李四（lisi@example.com）
> - user-3：王五（wangwu@example.com）

---

### 7. getUserById - 根据ID获取用户

**用户提问**: "查一下 user-1 的信息"

**AI 调用**:
```json
{
  "tool": "getUserById",
  "arguments": {
    "id": "user-1"
  }
}
```

**AI 回复**:
> user-1 的用户信息：
> - 姓名：张三
> - 邮箱：zhangsan@example.com
> - 注册时间：2026-04-03

---

### 8. getUserByName - 根据姓名搜索用户

**用户提问**: "帮我找一下叫张三的用户"

**AI 调用**:
```json
{
  "tool": "getUserByName",
  "arguments": {
    "name": "张三"
  }
}
```

**AI 回复**:
> 找到用户：张三（user-1），邮箱 zhangsan@example.com

---

### 9. createUser - 创建用户

**用户提问**: "添加一个新用户，姓名是赵六，邮箱 zhaoliu@example.com"

**AI 调用**:
```json
{
  "tool": "createUser",
  "arguments": {
    "name": "赵六",
    "email": "zhaoliu@example.com"
  }
}
```

**AI 回复**:
> ✅ 用户创建成功！
> - 用户ID：user-4
> - 姓名：赵六
> - 邮箱：zhaoliu@example.com

---

### 10. updateUser - 更新用户

**用户提问**: "把 user-1 的邮箱改成 new_zhangsan@example.com"

**AI 调用**:
```json
{
  "tool": "updateUser",
  "arguments": {
    "id": "user-1",
    "name": "张三",
    "email": "new_zhangsan@example.com"
  }
}
```

**AI 回复**:
> ✅ 用户信息已更新
> - user-1 的新邮箱：new_zhangsan@example.com

---

### 11. deleteUser - 删除用户

**用户提问**: "删除用户 user-3"

**AI 调用**:
```json
{
  "tool": "deleteUser",
  "arguments": {
    "id": "user-3"
  }
}
```

**AI 回复**:
> ✅ 用户 user-3（王五）已删除

---

## 👥 员工管理

### 12. getJobPosition - 查询员工岗位

**用户提问**: "张伟是什么岗位？"

**AI 调用**:
```json
{
  "tool": "getJobPosition",
  "arguments": {
    "name": "张伟"
  }
}
```

**AI 回复**:
> 张伟的岗位是：**后端开发**

---

### 13. getAllEmployees - 获取所有员工

**用户提问**: "我们公司有哪些员工？按岗位分类"

**AI 调用**:
```json
{
  "tool": "getAllEmployees",
  "arguments": {}
}
```

**AI 回复**:
> 公司共有 114 名员工，按岗位分类：
> - 后端开发：28人
> - 前端开发：28人
> - 产品经理：15人
> - 项目经理：15人
> - UI 设计：15人
> - 产品组长：13人

---

### 14. createEmployee - 创建员工

**用户提问**: "添加一个新员工，叫陈明，岗位是前端开发"

**AI 调用**:
```json
{
  "tool": "createEmployee",
  "arguments": {
    "name": "陈明",
    "position": "前端开发"
  }
}
```

**AI 回复**:
> ✅ 员工添加成功！
> - 姓名：陈明
> - 岗位：前端开发

---

### 15. updateEmployeePosition - 更新员工岗位

**用户提问**: "把陈明的岗位改成后端开发"

**AI 调用**:
```json
{
  "tool": "updateEmployeePosition",
  "arguments": {
    "name": "陈明",
    "position": "后端开发"
  }
}
```

**AI 回复**:
> ✅ 陈明的岗位已更新为：**后端开发**

---

### 16. deleteEmployee - 删除员工

**用户提问**: "删除员工陈明"

**AI 调用**:
```json
{
  "tool": "deleteEmployee",
  "arguments": {
    "id": 115
  }
}
```

**AI 回复**:
> ✅ 员工陈明已删除

---

## 🔗 组合调用示例

### 场景一：查询用户的订单

**用户提问**: "张三都买了什么？"

**AI 执行流程**:
1. 先调用 `getUserByName` 查找用户 ID
2. 再调用 `getOrdersByUserId` 查询订单

```
Step 1: getUserByName({"name": "张三"})
  → 返回: {"id": "user-1", ...}

Step 2: getOrdersByUserId({"userId": "user-1"})
  → 返回: [订单列表]
```

**AI 回复**:
> 张三（user-1）有 2 个订单：
> 1. iPhone 15 Pro - 7999元（已完成）
> 2. AirPods Pro - 1899元 x 2（待处理）

---

### 场景二：创建用户并下订单

**用户提问**: "新用户孙七，邮箱 sunqi@example.com，帮我创建一个订单买一台 Apple Watch，价格 3999 元"

**AI 执行流程**:
1. 先调用 `createUser` 创建用户
2. 再调用 `createOrder` 创建订单

```
Step 1: createUser({"name": "孙七", "email": "sunqi@example.com"})
  → 返回: {"id": "user-4", ...}

Step 2: createOrder({"userId": "user-4", "product": "Apple Watch", "quantity": 1, "price": 3999})
  → 返回: {"id": "ORDER-005", ...}
```

**AI 回复**:
> ✅ 操作完成！
> 1. 用户创建成功：孙七（user-4）
> 2. 订单创建成功：ORDER-005（Apple Watch - 3999元）

---

### 场景三：批量操作

**用户提问**: "把用户张三的订单 ORDER-001 改为已完成，然后查一下他现在有哪些订单"

**AI 执行流程**:
1. 调用 `updateOrderStatus` 更新订单状态
2. 调用 `getOrdersByUserId` 查询用户所有订单

```
Step 1: updateOrderStatus({"id": "ORDER-001", "status": "completed"})
  → 返回: {"id": "ORDER-001", "status": "completed", "updated": true}

Step 2: getOrdersByUserId({"userId": "user-1"})
  → 返回: [订单列表]
```

**AI 回复**:
> ✅ 订单 ORDER-001 已更新为已完成状态
> 
> 张三目前有 2 个订单：
> 1. iPhone 15 Pro - 7999元（已完成）
> 2. AirPods Pro - 1899元 x 2（待处理）

---

## 📋 工具参数参考

| 工具名称 | 必需参数 | 可选参数 | 说明 |
|---------|---------|---------|------|
| getAllOrders | 无 | 无 | 获取所有订单 |
| getOrderById | id (string) | 无 | 根据订单ID查询 |
| getOrdersByUserId | userId (string) | 无 | 根据用户ID查询 |
| createOrder | userId, product, quantity, price | status | 创建订单 |
| updateOrderStatus | id, status | 无 | 更新订单状态 |
| getAllUsers | 无 | 无 | 获取所有用户 |
| getUserById | id (string) | 无 | 根据用户ID查询 |
| getUserByName | name (string) | 无 | 根据姓名搜索 |
| createUser | name, email | 无 | 创建用户 |
| updateUser | id | name, email | 更新用户 |
| deleteUser | id (string) | 无 | 删除用户 |
| getJobPosition | name (string) | 无 | 查询员工岗位 |
| getAllEmployees | 无 | 无 | 获取所有员工 |
| createEmployee | name, position | 无 | 创建员工 |
| updateEmployeePosition | name, position | 无 | 更新岗位 |
| deleteEmployee | id (integer) | 无 | 删除员工 |

---

## 💡 提示

1. **中文参数**: URL 中的中文参数需要进行 URL 编码（如 `name=张伟` → `name=%E5%BC%A0%E4%BC%9F`）
2. **订单状态**: 支持 `pending`（待处理）、`shipped`（已发货）、`completed`（已完成）
3. **价格格式**: 使用数字类型，如 `7999` 或 `7999.00`
4. **员工数据**: 系统预置 114 名员工数据，涵盖 6 种岗位
