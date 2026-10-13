import { test, expect } from 'claude-code/testing'

import { compact, segments, until } from './register'

test('segments stack account, session and free to the width', () => {
  expect(segments(0, 0, 10)).toEqual({ account: 0, session: 0, free: 10 })
  expect(segments(50, 0, 10)).toEqual({ account: 5, session: 0, free: 5 })
  expect(segments(50, 20, 10)).toEqual({ account: 3, session: 2, free: 5 })
  expect(segments(150, 10, 10).free).toBe(0)
})

test('a session share too small to round still shows one cell', () => {
  expect(segments(40, 0.2, 10)).toEqual({ account: 3, session: 1, free: 6 })
})

test('compact and until format', () => {
  expect(compact(999)).toBe('999')
  expect(compact(445_100)).toBe('445.1k')
  expect(compact(2_500_000)).toBe('2.5M')
  const now = Date.parse('2026-10-14T00:00:00Z')
  expect(until('2026-10-14T04:51:00Z', now)).toBe('4h51m')
  expect(until('2026-10-18T19:00:00Z', now)).toBe('4d19h')
  expect(until(undefined, now)).toBe('')
})
