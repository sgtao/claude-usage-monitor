import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Limit, Tokens } from '../types'

const limits = atom({ plugin: 'usage-monitor', key: 'limits' } as const, [])
const base = atom({ plugin: 'usage-monitor', key: 'base' } as const, {})
const tokens = atom({ plugin: 'usage-monitor', key: 'tokens' } as const, {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  turns: 0,
})
const usd = atom({ plugin: 'usage-monitor', key: 'usd' } as const, null)
const isHidden = atom({ plugin: 'usage-monitor', key: 'isHidden' } as const, false)

const LABEL: Record<string, string> = {
  five_hour: '5h',
  seven_day: '7d',
  spend_limit: '$ ',
}

/** Cells of a stacked bar: account share, this session's share, the rest free. */
export const segments = (
  percent: number,
  gain: number,
  width: number,
): { account: number; session: number; free: number } => {
  const total = Math.max(0, Math.min(100, percent))
  const mine = Math.max(0, Math.min(total, gain))
  const cells = (p: number): number => Math.round((p / 100) * width)
  const used = Math.min(width, cells(total))
  const session = mine > 0 ? Math.min(used, Math.max(1, cells(mine))) : 0
  return { account: used - session, session, free: width - used }
}

export const compact = (n: number): string =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n)

export const until = (iso: string | undefined, now: number): string => {
  if (iso === undefined) return ''
  const mins = Math.max(0, Math.round((Date.parse(iso) - now) / 60000))
  const d = Math.floor(mins / 1440)
  const h = Math.floor((mins % 1440) / 60)
  const m = mins % 60
  return d > 0 ? `${d}d${h}h` : `${h}h${String(m).padStart(2, '0')}m`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'usage-monitor', description: 'USAGE MONITOR の表示/非表示を切り替え' })
    const usage = await $.session.usage()
    await update($, limits, () => usage.rateLimits)
    await update($, base, () =>
      Object.fromEntries(usage.rateLimits.map(l => [l.kind, l.percentUsed])),
    )
    await update($, usd, () => usage.cost?.usd ?? null)

    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    await update($, limits, () => e.rateLimits)
    // The first reading seen for a window is this session's starting line.
    await update($, base, b => {
      const out = { ...b }
      for (const l of e.rateLimits) if (out[l.kind] === undefined) out[l.kind] = l.percentUsed
      return out
    })
    await update($, usd, () => e.cost?.usd ?? null)

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const u = e.usage
    if (e.agentId === undefined && u !== undefined) {
      await update($, tokens, t => ({
        input: t.input + u.input_tokens,
        output: t.output + u.output_tokens,
        cacheRead: t.cacheRead + u.cache_read_input_tokens,
        cacheWrite: t.cacheWrite + (u.cache_creation_input_tokens ?? 0),
        turns: t.turns + 1,
      }))
    }

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || (await read($, isHidden))) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const lim: Limit[] = await read($, limits)
    const b = await read($, base)
    const t: Tokens = await read($, tokens)
    const cost = await read($, usd)
    const now = await $.clock.now()

    const width = Math.max(10, Math.min(60, e.props.bodyColumns - 42))
    const gain = (l: Limit): number => Math.max(0, l.percentUsed - (b[l.kind] ?? l.percentUsed))
    const total = t.input + t.output + t.cacheRead + t.cacheWrite

    return (
      <Box flexDirection="column" borderStyle="round" paddingX={1}>
        <Box justifyContent="space-between">
          <Text bold color="cyan">USAGE MONITOR</Text>
          <Text>
            <Text color="cyan">■</Text>
            <Text> account </Text>
            <Text color="magenta">■</Text>
            <Text> this session </Text>
            <Text dimColor>░</Text>
            <Text> free </Text>
          </Text>
          <Button key="hide" label="[x]" onPress={() => update($, isHidden, () => true)} />
        </Box>
        {lim.length === 0 ? (
          <Text dimColor>waiting for the first rate-limit reading…</Text>
        ) : (
          lim.map(l => {
            const g = gain(l)
            const s = segments(l.percentUsed, g, width)

            return (
              <Box key={l.kind} gap={1}>
                <Text bold>{LABEL[l.kind] ?? l.kind}</Text>
                <Text>
                  <Text dimColor>[</Text>
                  <Text color="cyan">{'█'.repeat(s.account)}</Text>
                  <Text color="magenta">{'█'.repeat(s.session)}</Text>
                  <Text dimColor>{'░'.repeat(s.free)}</Text>
                  <Text dimColor>]</Text>
                </Text>
                <Text color="cyan">{l.percentUsed.toFixed(1)}%</Text>
                <Text color="magenta">+{g.toFixed(1)}%</Text>
                <Text dimColor>⟳ {until(l.resetsAt, now)}</Text>
              </Box>
            )
          })
        )}
        <Box gap={1}>
          <Text bold>ses</Text>
          <Text color="magenta">{compact(total)}</Text>
          <Text dimColor>tok │</Text>
          <Text dimColor>in </Text>
          <Text>{compact(t.input)}</Text>
          <Text dimColor>out </Text>
          <Text>{compact(t.output)}</Text>
          <Text dimColor>cache </Text>
          <Text>{compact(t.cacheRead)}</Text>
          {cost !== null ? <Text dimColor>│ cost </Text> : null}
          {cost !== null ? <Text>${cost.toFixed(2)}</Text> : null}
        </Box>
      </Box>
    )
  })

  on('command.run', { command: 'usage-monitor' }, async $ => {
    await update($, isHidden, h => !h)

    return { text: 'USAGE MONITOR を切り替えました。' }
  })
}
