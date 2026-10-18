import type { Todo } from '../types'

function TodoItem({ todo }: { todo: Todo }) {
  const icon =
    todo.status === 'completed'
      ? '✓'
      : todo.status === 'in_progress'
        ? '→'
        : '○'
  const color =
    todo.status === 'completed'
      ? 'text-emerald-700 bg-emerald-50'
      : todo.status === 'in_progress'
        ? 'text-sky-700 bg-sky-50'
        : 'text-slate-600 bg-slate-50'

  return (
    <li
      className={`flex items-start gap-2 rounded-md px-3 py-2 text-sm ${color}`}
    >
      <span className="mt-0.5 font-mono text-xs">{icon}</span>
      <span>{todo.content}</span>
    </li>
  )
}

export function TodoList({ todos }: { todos: Todo[] }) {
  const completed = todos.filter((t) => t.status === 'completed').length
  const percentage = todos.length
    ? Math.round((completed / todos.length) * 100)
    : 0

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-slate-800">Agent 进度</h2>
        <span className="text-xs text-slate-500">
          {completed}/{todos.length} 任务
        </span>
      </div>
      <div className="mb-3 h-2 overflow-hidden rounded-full bg-slate-100">
        <div
          className="h-full rounded-full bg-emerald-500 transition-all duration-300"
          style={{ width: `${percentage}%` }}
        />
      </div>
      <ul className="space-y-1">
        {todos.map((todo, i) => (
          <TodoItem key={`${todo.content}-${i}`} todo={todo} />
        ))}
      </ul>
    </div>
  )
}
