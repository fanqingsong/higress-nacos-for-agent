# MCP Chat UI

React 对话界面，通过 `@langchain/react` 的 `useStream` 连接 LangGraph Agent（默认 http://localhost:2024）。

```bash
npm install
npm run dev
```

环境变量 `VITE_AGENT_URL` 可在构建时指定（见根目录 `.env.example`）。
