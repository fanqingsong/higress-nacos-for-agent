import { useStream, useToolCalls } from '@langchain/react'
import { AIMessage, HumanMessage, ToolMessage } from '@langchain/core/messages'
import { useEffect, useMemo, useState } from 'react'
import type { AgentState } from '../types'
import { ChatInput } from './ChatInput'
import { TodoList } from './TodoList'
import { ToolCard } from './ToolCard'

const AGENT_URL =
  import.meta.env.VITE_AGENT_URL?.replace(/\/$/, '') ||
  'http://localhost:2024'
const ASSISTANT_ID = 'deep_agent_todo_list'

function messageText(msg: { text?: string; content?: unknown }): string {
  if (typeof msg.text === 'string' && msg.text.trim()) return msg.text
  const content = msg.content
  if (typeof content === 'string') return content
  if (!Array.isArray(content)) return ''
  return content
    .map((block) => {
      if (typeof block === 'string') return block
      if (block && typeof block === 'object' && 'text' in block) {
        const text = (block as { text?: unknown }).text
        return typeof text === 'string' ? text : ''
      }
      return ''
    })
    .join('')
    .trim()
}

const SUGGESTIONS = [
  '帮我查一下目前有哪些订单？',
  '张三都买了什么？',
  '张伟是什么岗位？',
]

export function AgentChat() {
  const stream = useStream<AgentState>({
    apiUrl: AGENT_URL,
    assistantId: ASSISTANT_ID,
  })
  const toolCalls = useToolCalls(stream)
  const todos = stream.values?.todos ?? []
  const [agentOk, setAgentOk] = useState<boolean | null>(null)

  useEffect(() => {
    fetch(`${AGENT_URL}/ok`)
      .then((r) => setAgentOk(r.ok))
      .catch(() => setAgentOk(false))
  }, [])

  const toolCallsByMessageId = useMemo(() => {
    const map = new Map<string, typeof toolCalls>()
    for (const msg of stream.messages) {
      if (!AIMessage.isInstance(msg) || !msg.tool_calls?.length) continue
      const ids = new Set(msg.tool_calls.map((tc) => tc.id).filter(Boolean))
      const matched = toolCalls.filter((tc) => ids.has(tc.callId))
      if (matched.length) map.set(msg.id ?? '', matched)
    }
    return map
  }, [stream.messages, toolCalls])

  function handleSubmit(text: string) {
    stream.submit(
      { messages: [{ type: 'human', content: text }] },
      { config: { recursion_limit: 100 } },
    )
  }

  return (
    <div className="flex h-screen flex-col bg-slate-100">
      <header className="border-b border-slate-200 bg-white px-4 py-3 shadow-sm">
        <div className="mx-auto flex max-w-3xl flex-wrap items-center justify-between gap-2">
          <div>
            <h1 className="text-lg font-semibold text-slate-900">
              Nacos MCP Deep Agent
            </h1>
            <p className="text-xs text-slate-500">
              LangGraph · Higress SSE · 16 个 MCP 工具
            </p>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span
              className={`inline-flex items-center gap-1 rounded-full px-2 py-1 ${
                agentOk === true
                  ? 'bg-emerald-100 text-emerald-800'
                  : agentOk === false
                    ? 'bg-red-100 text-red-800'
                    : 'bg-slate-100 text-slate-600'
              }`}
            >
              <span className="h-1.5 w-1.5 rounded-full bg-current" />
              Agent {agentOk === true ? '在线' : agentOk === false ? '离线' : '…'}
            </span>
            {stream.isLoading && (
              <span className="text-sky-600">思考中…</span>
            )}
          </div>
        </div>
      </header>

      {todos.length > 0 && (
        <div className="border-b border-slate-200 bg-slate-50 px-4 py-3">
          <div className="mx-auto max-w-3xl">
            <TodoList todos={todos} />
          </div>
        </div>
      )}

      <main className="flex-1 overflow-y-auto px-4 py-6">
        <div className="mx-auto max-w-3xl space-y-4">
          {stream.messages.length === 0 && (
            <div className="rounded-lg border border-dashed border-slate-300 bg-white p-6 text-center">
              <p className="mb-4 text-sm text-slate-600">
                通过自然语言调用 Higress 暴露的 MCP 工具（用户 / 订单 / 员工）
              </p>
              <div className="flex flex-wrap justify-center gap-2">
                {SUGGESTIONS.map((q) => (
                  <button
                    key={q}
                    type="button"
                    onClick={() => handleSubmit(q)}
                    className="rounded-full border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs text-sky-800 hover:bg-sky-100"
                  >
                    {q}
                  </button>
                ))}
              </div>
            </div>
          )}

          {stream.messages.map((msg) => {
            if (HumanMessage.isInstance(msg)) {
              return (
                <div key={msg.id} className="flex justify-end">
                  <div className="max-w-[85%] rounded-2xl rounded-br-md bg-sky-600 px-4 py-2 text-sm text-white">
                    {messageText(msg) || JSON.stringify(msg.content)}
                  </div>
                </div>
              )
            }

            if (AIMessage.isInstance(msg)) {
              const text = messageText(msg)
              const cards = toolCallsByMessageId.get(msg.id ?? '') ?? []
              if (!text && cards.length === 0 && !msg.tool_calls?.length) {
                return null
              }
              return (
                <div key={msg.id} className="flex justify-start">
                  <div className="max-w-[90%]">
                    {text ? (
                      <div className="rounded-2xl rounded-bl-md border border-slate-200 bg-white px-4 py-2 text-sm text-slate-800 shadow-sm">
                        {text}
                      </div>
                    ) : null}
                    {cards.map((tc) => (
                      <ToolCard key={tc.callId} toolCall={tc} />
                    ))}
                  </div>
                </div>
              )
            }

            if (ToolMessage.isInstance(msg)) {
              const output = messageText(msg) || String(msg.content ?? '')
              const isError =
                msg.status === 'error' || output.startsWith('Error:')
              return (
                <div key={msg.id} className="flex justify-start">
                  <div className="max-w-[90%]">
                    <ToolCard
                      toolCall={{
                        callId: msg.tool_call_id || msg.id || '',
                        name: msg.name || 'tool',
                        args: {},
                        output,
                        status: isError ? 'error' : 'finished',
                      }}
                    />
                  </div>
                </div>
              )
            }

            return null
          })}

          {stream.isLoading && (
            <div className="flex justify-start">
              <div className="rounded-2xl rounded-bl-md border border-sky-100 bg-sky-50 px-4 py-2 text-sm text-sky-800">
                正在调用模型 / MCP 工具，请稍候…
              </div>
            </div>
          )}

          {stream.error != null && (
            <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-800">
              {stream.error instanceof Error
                ? stream.error.message
                : JSON.stringify(stream.error)}
            </div>
          )}
        </div>
      </main>

      <div className="mx-auto w-full max-w-3xl">
        <ChatInput onSubmit={handleSubmit} disabled={stream.isLoading} />
      </div>
    </div>
  )
}
