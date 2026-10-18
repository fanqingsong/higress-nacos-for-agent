export type TodoStatus = 'pending' | 'in_progress' | 'completed'

export interface Todo {
  content: string
  status: TodoStatus
}

export interface AgentState {
  todos?: Todo[]
  messages?: unknown[]
}
