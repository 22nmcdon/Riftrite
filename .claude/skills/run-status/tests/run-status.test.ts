import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { ProgressFile } from '../types'
import {
  STALE_MS,
  STALE_UNITS,
  STALE_UNKNOWN_MS,
  buildGroups,
  duration,
  endToast,
  eta,
  groupState,
  parseProgress,
  pace,
  partState,
  statusLine,
} from '../hooks/model'

const NOW = 10_000_000
const DIR = '/repo/.progress'

function file(over: Partial<ProgressFile> = {}): ProgressFile {
  return {
    id: 'run_runner-1',
    label: 'runs (the good bot)',
    kind: 'runs',
    total: 10,
    done: 0,
    started_ms: NOW - 60_000,
    updated_ms: NOW - 1_000,
    group: 'g',
    part: '',
    pid: 1,
    status: 'running',
    ...over,
  }
}

describe('reading files', () => {
  test('a progress file parses; anything else is skipped', () => {
    const text = JSON.stringify({ label: 'x', kind: 'runs', total: 4, done: 1, started_ms: 1, updated_ms: 2, group: 'g', part: '0/2', pid: 7, status: 'running' })
    expect(parseProgress('run_runner-7.json', text)).toEqual({ id: 'run_runner-7', label: 'x', kind: 'runs', total: 4, done: 1, started_ms: 1, updated_ms: 2, group: 'g', part: '0/2', pid: 7, status: 'running' })
    expect(parseProgress('a.json', '{"total": 4')).toBeUndefined()
    expect(parseProgress('a.json', JSON.stringify({ total: 4, done: 1 }))).toBeUndefined()
    expect(parseProgress('a.json', JSON.stringify({ total: 4, done: 1, started_ms: 1, updated_ms: 2, pid: 3, status: 'odd' }))).toBeUndefined()
  })
})

describe('states', () => {
  test('done and failed come from the file, dead from a gone process', () => {
    expect(partState(file({ status: 'done' }), false, NOW, undefined)).toBe('done')
    expect(partState(file({ status: 'failed' }), true, NOW, undefined)).toBe('failed')
    expect(partState(file(), false, NOW, undefined)).toBe('dead')
    expect(partState(file({ done: 3 }), true, NOW, undefined)).toBe('running')
  })

  test('stale after 10 units of its pace with no progress (at least 60s)', () => {
    const quick = file({ done: 6, updated_ms: NOW - STALE_MS - 1 })
    expect(partState(quick, true, NOW, 1_000)).toBe('stale')
    // Runs of about 80s: 8 minutes on one run isn't stale yet, 14 is.
    const slow = file({ done: 2, updated_ms: NOW - 8 * 60_000 })
    expect(partState(slow, true, NOW, 80_000)).toBe('running')
    expect(partState(slow, true, NOW + 6 * 60_000, 80_000)).toBe('stale')
    expect(STALE_UNITS * 80_000).toBe(800_000)
    // No pace anywhere yet: STALE_UNKNOWN_MS.
    const fresh = file({ done: 0, started_ms: NOW - 5 * 60_000, updated_ms: NOW - 5 * 60_000 })
    expect(partState(fresh, true, NOW, undefined)).toBe('running')
    expect(partState(fresh, true, NOW - 5 * 60_000 + STALE_UNKNOWN_MS + 1, undefined)).toBe('stale')
  })

  test("a group's state: dead, stale, running, failed, then done", () => {
    expect(groupState(['done', 'running', 'dead'])).toBe('dead')
    expect(groupState(['running', 'stale'])).toBe('stale')
    expect(groupState(['done', 'running'])).toBe('running')
    expect(groupState(['done', 'failed'])).toBe('failed')
    expect(groupState(['done', 'done'])).toBe('done')
  })
})

describe('the ETA', () => {
  test("a process's pace leans on the group's until it has its own", () => {
    const one = file({ done: 1, started_ms: NOW - 300_000, updated_ms: NOW })
    expect(pace(one, 60_000)).toBe((300_000 + 6 * 60_000) / 7)
    const many = file({ done: 30, started_ms: NOW - 9_000_000, updated_ms: NOW })
    expect(Math.round(pace(many, 60_000)!)).toBe(Math.round((9_000_000 + 6 * 60_000) / 36))
    expect(pace(file({ done: 0 }), 60_000)).toBe(60_000)
    expect(pace(file({ done: 2, started_ms: NOW - 100_000, updated_ms: NOW }), undefined)).toBe(50_000)
    expect(pace(file({ done: 0 }), undefined)).toBeUndefined()
  })

  test('the unit under way counts toward what is left', () => {
    expect(eta(file({ total: 10, done: 8, updated_ms: NOW - 20_000 }), NOW, 60_000)).toBe(100_000)
    expect(eta(file({ total: 10, done: 8, updated_ms: NOW - 500_000 }), NOW, 60_000)).toBe(60_000)
    expect(eta(file({ total: 10, done: 10 }), NOW, 60_000)).toBe(0)
    expect(eta(file({ total: 10, done: 0 }), NOW, undefined)).toBeNull()
  })

  /** Eight processes `minutes` in, each with `done` of 36 finished 30s ago. */
  function snapshot(minutes: number, done: number[]) {
    return done.map((d, k) => ({
      file: file({ id: `p${k}`, group: 'g', part: `${k}/8`, total: 36, done: d, started_ms: NOW - minutes * 60_000, updated_ms: d > 0 ? NOW - 30_000 : NOW - minutes * 60_000 }),
      isAlive: true,
    }))
  }

  test("early on it doesn't take the worst of eight guesses (the playtester's case)", () => {
    // 5 minutes in, then 13 (a later NOW is the same as an earlier start).
    const [early] = buildGroups(snapshot(5, [3, 3, 1, 3, 1, 2, 4, 0]), NOW, {})
    const [later] = buildGroups(snapshot(13, [7, 8, 5, 9, 6, 9, 9, 3]), NOW, {})
    const earlyMin = early!.etaMs! / 60_000
    const laterMin = later!.etaMs! / 60_000
    expect(earlyMin).toBeLessThan(120)
    expect(Math.abs(earlyMin - (laterMin + 8))).toBeLessThan(0.35 * earlyMin)
    expect(early!.parts.every(p => p.state === 'running')).toBe(true)
  })

  test("late on it's the slowest process's", () => {
    // 7 of 8 done in 33 minutes; the last at 12 of 36.
    const started = NOW - 33 * 60_000
    const seen = Array.from({ length: 8 }, (_, k) => ({
      file: file({ id: `p${k}`, group: 'g', part: `${k}/8`, total: 36, started_ms: started, ...(k === 5 ? { done: 12, updated_ms: NOW - 1_000 } : { done: 36, status: 'done' as const, updated_ms: NOW - 60_000 }) }),
      isAlive: true,
    }))
    const [group] = buildGroups(seen, NOW, {})
    const minutes = group!.etaMs! / 60_000
    expect(minutes).toBeGreaterThan(20)
    expect(minutes).toBeLessThan(70)
  })
})

describe('groups and text', () => {
  test('parts group by group, sorted by part, summed', () => {
    const groups = buildGroups(
      [
        { file: file({ id: 'a', group: 'g1', part: '1/2', total: 5, done: 2, pid: 2 }), isAlive: true },
        { file: file({ id: 'b', group: 'g1', part: '0/2', total: 5, done: 3, pid: 1 }), isAlive: true },
        { file: file({ id: 'c', group: 'g2', label: 'sim runner: paths report', kind: 'encounters', started_ms: NOW - 10_000, status: 'done', done: 10, updated_ms: NOW - 2_000 }), isAlive: false },
      ],
      NOW,
      {},
    )
    expect(groups.map(g => g.id)).toEqual(['g2', 'g1'])
    const g1 = groups[1]!
    expect([g1.done, g1.total, g1.state]).toEqual([5, 10, 'running'])
    expect(g1.parts.map(p => p.part)).toEqual(['1 of 2', '2 of 2'])
    expect(groups[0]!.elapsedMs).toBe(8_000)
    expect(groups[0]!.etaMs).toBeNull()
  })

  test('the status line counts what runs, and is cleared when nothing does', () => {
    const groups = buildGroups([{ file: file({ done: 5 }), isAlive: true }], NOW, {})
    expect(statusLine(groups)).toBe('1 run · 50% · ~58s left')
    expect(statusLine(buildGroups([{ file: file({ status: 'done', done: 10 }), isAlive: true }], NOW, {}))).toBeUndefined()
    expect(duration(72 * 60_000)).toBe('1h12m')
  })

  test('a toast when a group ends, once', () => {
    const [done] = buildGroups([{ file: file({ status: 'done', done: 10 }), isAlive: true }], NOW, {})
    expect(endToast(done!, 'running')).toMatch(/done, 10 runs in/)
    expect(endToast(done!, 'done')).toBeUndefined()
    const [dead] = buildGroups([{ file: file({ part: '2/4' }), isAlive: false }], NOW, {})
    expect(endToast(dead!, 'running')).toBe('runs (the good bot): a process died (3 of 4)')
  })
})

/** The world beneath the mod: the progress folder, live pids, and what it showed. */
function world(on: On) {
  const files = new Map<string, Record<string, unknown>>()
  const alive = new Set<number>()
  const zombies = new Set<number>()
  const shown = { status: [] as (string | undefined)[], toasts: [] as string[], logs: [] as string[], removed: [] as string[], opened: 0 }
  mock.env(on, { RIFTRITE_PROGRESS_DIR: DIR })
  mock.store(on)
  const clock = mock.clock(on, { now: NOW })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('session.root', () => ({ value: '/repo' }))
  on('command.register', (_$, e) => ({ value: { command: e.name } }))
  on('fs.exists', (_$, e) => ({ value: e.path === DIR }))
  on('fs.list', () => ({ value: [...files.keys()].map(name => ({ name, kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false })) }))
  on('fs.read', (_$, e) => ({ value: JSON.stringify(files.get(e.path.slice(DIR.length + 1))) }))
  on('process.run', (_$, e) => {
    if (e.argv[0] === 'rm') shown.removed.push(String(e.argv[2]))
    // ps -o stat= -p <pid>: nothing for a gone process, Z for a zombie.
    const pid = Number(e.argv[4])
    const isPs = e.argv[0] === 'ps'
    const stat = !isPs ? '' : zombies.has(pid) ? 'Z\n' : alive.has(pid) ? 'S\n' : ''
    const exitCode = isPs && stat === '' ? 1 : 0
    return { value: { exitCode, stdout: stat, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.status', (_$, e) => {
    shown.status.push(e.text)
    return { value: undefined }
  })
  on('ui.toast', (_$, e) => {
    shown.toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.log', (_$, e) => {
    shown.logs.push(e.text)
    return { value: undefined }
  })
  on('ui.open', () => {
    shown.opened += 1
    return { value: { isPlaced: true as const } }
  })
  const put = (name: string, data: Partial<ProgressFile>) => {
    const { id: _id, ...rest } = file(data)
    files.set(`${name}.json`, { ...rest, started_ms: clock.now() - 60_000, updated_ms: clock.now(), ...data })
  }
  return { files, alive, zombies, shown, clock, put }
}

describe('the mod', () => {
  test('polls every 2s: status line, a dead process, its toast', async ($, on) => {
    const w = world(on)
    w.alive.add(11).add(12)
    w.put('run_runner-11', { group: 'rr', part: '0/2', total: 5, done: 2, pid: 11 })
    w.put('run_runner-12', { group: 'rr', part: '1/2', total: 5, done: 3, pid: 12 })
    await $.session.start({ cwd: '/repo', surface: null, isInteractive: true })
    expect(w.shown.status.at(-1)).toMatch(/^1 run · 50% · /)
    expect(w.shown.toasts).toEqual([])
    w.alive.delete(12)
    await w.clock.advance(2000)
    expect(w.shown.status.at(-1)).toMatch(/^1 run · 50% · .* · 1 dead$/)
    expect(w.shown.toasts).toEqual(['runs (the good bot): a process died (2 of 2)'])
    await w.clock.advance(2000)
    expect(w.shown.toasts.length).toBe(1)
  })

  test('notices in the conversation: loaded, each quarter, and the end', async ($, on) => {
    const w = world(on)
    const session = mock.session(on)
    const notices = () => session.appended().map(r => JSON.stringify(r.message.content)).filter(t => t.includes('run-status: '))
    w.alive.add(61)
    w.put('run_runner-61', { group: 'q', total: 8, done: 1, pid: 61 })
    await $.session.start({ cwd: '/repo', surface: null, isInteractive: true })
    expect(notices()).toEqual([JSON.stringify([{ type: 'text', text: 'run-status: watching .progress/: 1 run · 12% · ~7m left' }])])
    w.put('run_runner-61', { group: 'q', total: 8, done: 1, pid: 61 })
    await w.clock.advance(2000)
    expect(notices().length).toBe(1)
    w.put('run_runner-61', { group: 'q', total: 8, done: 4, pid: 61 })
    await w.clock.advance(2000)
    expect(notices().at(-1)).toMatch(/runs \(the good bot\): 50% · 4\/8 runs · .* · running/)
    w.put('run_runner-61', { group: 'q', total: 8, done: 5, pid: 61 })
    await w.clock.advance(2000)
    expect(notices().length).toBe(2)
    w.put('run_runner-61', { group: 'q', total: 8, done: 8, status: 'done', pid: 61 })
    await w.clock.advance(2000)
    expect(notices().at(-1)).toMatch(/runs \(the good bot\): done, 8 runs in/)
  })

  test('a zombie (exited, not yet reaped) is dead', async ($, on) => {
    const w = world(on)
    w.alive.add(13)
    w.zombies.add(14)
    w.put('run_runner-13', { group: 'rr', part: '0/2', total: 5, done: 1, pid: 13 })
    w.put('run_runner-14', { group: 'rr', part: '1/2', total: 5, done: 1, pid: 14 })
    await $.session.start({ cwd: '/repo', surface: null, isInteractive: true })
    expect(w.shown.status.at(-1)).toMatch(/· 1 dead$/)
  })

  test('/runs opens the pane: a card per group, a bar per part', async ($, on) => {
    const w = world(on)
    w.alive.add(21).add(22).add(31)
    w.put('run_runner-21', { group: 'rr', part: '0/2', total: 4, done: 1, pid: 21 })
    w.put('run_runner-22', { group: 'rr', part: '1/2', total: 4, done: 4, status: 'done', pid: 22 })
    w.put('sim_runner-31', { group: 'sim_runner-31', label: 'sim runner: paths report', kind: 'encounters', total: 25, done: 5, pid: 31 })
    const ran = await $.command.run({ command: 'runs' })
    expect(ran.text).toContain('sim runner: paths report: 20% · 5/25 encounters')
    expect(ran.text).toContain('runs (the good bot): 62% · 5/8 runs')
    expect(ran.text).toContain('  1 of 2: 1/4')
    expect(ran.text).toContain('  2 of 2: 4/4 done')
    expect(w.shown.opened).toBe(1)
    for (const surface of ['terminal', 'desktop'] as const) {
      const ui = await $.ui.mount({
        plugin: 'run-status',
        surface,
        component: 'Pane',
        requestId: 'run-status',
        props: { title: 'Runs', isFocused: false, bodyColumns: 80, placement: 'dock' },
      })
      expect(await ui.find({ type: 'Text', text: 'sim runner: paths report' })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: /5\/25 encounters/ })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: /1 of 2 .* 1\/4/ })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: /2 of 2 .* 4\/4 done/ })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: /^running$/ })).toBeDefined()
      await ui.unmount()
    }
  })

  test('a finished group is remembered, and its pace is the next ETA', async ($, on) => {
    const w = world(on)
    w.alive.add(41)
    w.put('placement_check-41', { group: 'pc', label: 'placement check', kind: 'encounters', total: 20, done: 10, pid: 41, started_ms: NOW - 100_000, updated_ms: NOW })
    await $.session.start({ cwd: '/repo', surface: null, isInteractive: true })
    w.files.set('placement_check-41.json', { ...w.files.get('placement_check-41.json'), status: 'done', done: 20, updated_ms: NOW + 100_000 })
    await w.clock.advance(2000)
    expect(w.shown.toasts.at(-1)).toMatch(/^placement check: done, 20 encounters in 3m$/)
    w.files.clear()
    w.alive.add(42)
    w.put('placement_check-42', { group: 'pc2', label: 'placement check', kind: 'encounters', total: 20, done: 0, pid: 42 })
    await w.clock.advance(2000)
    expect(w.shown.status.at(-1)).toBe('1 run · 0% · ~3m left')
  })

  test('/runs clear deletes finished, failed, and dead files', async ($, on) => {
    const w = world(on)
    w.alive.add(51)
    w.put('a-50', { group: 'a', status: 'done', done: 10, pid: 50 })
    w.put('b-51', { group: 'b', pid: 51 })
    w.put('c-52', { group: 'c', status: 'failed', pid: 52 })
    w.put('d-53', { group: 'd', pid: 53 })
    const ran = await $.command.run({ command: 'runs', args: 'clear' })
    expect(ran.text).toBe('Cleared 3 progress files.')
    expect(w.shown.removed.sort()).toEqual([`${DIR}/a-50.json`, `${DIR}/c-52.json`, `${DIR}/d-53.json`])
  })
})
