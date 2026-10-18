function truncate(text: string, max = 400): string {
  if (text.length <= max) return text
  return `${text.slice(0, max)}…`
}

export function ToolCard({
  toolCall,
}: {
  toolCall: {
    callId?: string
    name?: string
    args?: unknown
    output?: unknown
    status?: string
  }
}) {
  const name = toolCall.name ?? 'unknown'
  const status = toolCall.status ?? 'pending'
  const args =
    typeof toolCall.args === 'string'
      ? toolCall.args
      : JSON.stringify(toolCall.args ?? {}, null, 2)
  const output =
    toolCall.output != null
      ? typeof toolCall.output === 'string'
        ? toolCall.output
        : JSON.stringify(toolCall.output, null, 2)
      : null

  const statusColor =
    status === 'finished'
      ? 'border-emerald-200 bg-emerald-50/80'
      : status === 'error'
        ? 'border-red-200 bg-red-50/80'
        : 'border-amber-200 bg-amber-50/80'

  return (
    <div
      className={`mt-2 rounded-md border px-3 py-2 text-xs ${statusColor}`}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-mono font-semibold text-slate-800">{name}</span>
        <span className="text-slate-500">{status}</span>
      </div>
      {args && args !== '{}' && (
        <pre className="mt-1 overflow-x-auto whitespace-pre-wrap text-slate-600">
          {truncate(args)}
        </pre>
      )}
      {output && (
        <pre className="mt-2 max-h-40 overflow-auto rounded bg-white/70 p-2 text-slate-700">
          {truncate(output, 800)}
        </pre>
      )}
    </div>
  )
}
