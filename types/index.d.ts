export type Limit = { kind: string; percentUsed: number; resetsAt?: string }

export type Tokens = {
  input: number
  output: number
  cacheRead: number
  cacheWrite: number
  turns: number
}

declare module 'claude-code' {
  interface PluginState {
    'usage-monitor': {
      limits: Limit[]
      base: Record<string, number>
      tokens: Tokens
      usd: number | null
      isHidden: boolean
    }
  }
}
