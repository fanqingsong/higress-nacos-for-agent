import { useState, type FormEvent } from 'react'

export function ChatInput({
  onSubmit,
  disabled,
}: {
  onSubmit: (text: string) => void
  disabled?: boolean
}) {
  const [text, setText] = useState('')

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    const trimmed = text.trim()
    if (!trimmed || disabled) return
    onSubmit(trimmed)
    setText('')
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex gap-2 border-t border-slate-200 bg-white p-4"
    >
      <input
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="输入问题，例如：张三都买了什么？"
        disabled={disabled}
        className="flex-1 rounded-lg border border-slate-300 px-4 py-2 text-sm outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 disabled:opacity-50"
      />
      <button
        type="submit"
        disabled={disabled || !text.trim()}
        className="rounded-lg bg-sky-600 px-4 py-2 text-sm font-medium text-white hover:bg-sky-700 disabled:cursor-not-allowed disabled:opacity-50"
      >
        发送
      </button>
    </form>
  )
}
