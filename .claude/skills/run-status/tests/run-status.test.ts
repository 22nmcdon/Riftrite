import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { ProgressFile } from '../types'
import {
  STALE_MS,
  STALE_UNKNOWN_MS,
  WINDOW_MS,
  addSample,
  buildGroups,
  duration,
  endToast,
  eta,
  groupState,
  parseProgress,
  partState,
  statusLine,
  windowRate,
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

  test('stale after 60s with no progress, longer when units are slow', () => {
    const fast = file({ done: 6, started_ms: NOW - 60_000, updated_ms: NOW - STALE_MS - 1 })
    expect(partState(fast, true, NOW, undefined)).toBe('stale')
    // A run of 7 minutes: 3 minutes since the last one isn't stale yet.
    const slow = file({ done: 2, started_ms: NOW - 17 * 60_000, updated_ms: NOW - 3 * 60_000 })
    expect(partState(slow, true, NOW, undefined)).toBe('running')
    expect(partState(slow, true, NOW + 20 * 60_000, undefined)).toBe('stale')
    // No unit done yet: history's pace, else STALE_UNKNOWN_MS.
    const fresh = file({ done: 0, started_ms: NOW - 5 * 60_000, updated_ms: NOW - 5 * 60_000 })
    expect(partState(fresh, true, NOW, undefined)).toBe('running')
    expect(partState(fresh, true, NOW, 30_000)).toBe('stale')
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
  test('from the last 5 minutes, not from the start', () => {
    // Slow at first (10 in the first hour), fast lately (5 a minute).
    let samples = [{ t: NOW - 3_600_000, done: 0 }]
    for (let m = 5; m >= 0; m--) samples = addSample(samples, NOW - m * 60_000, 10 + (5 - m) * 5)
    expect(windowRate(samples, NOW)).toBe(25 / 300_000)
    expect(Math.round(eta(100, 35, 3_600_000, samples, NOW, undefined) ?? 0)).toBe(13 * 60_000)
  })

  test('history before there is enough data, then the rate so far, then nothing', () => {
    const short = [{ t: NOW - 10_000, done: 1 }, { t: NOW, done: 2 }]
    expect(windowRate(short, NOW)).toBeUndefined()
    expect(eta(10, 2, 60_000, short, NOW, 5_000)).toBe(40_000)
    expect(eta(10, 2, 60_000, short, NOW, undefined)).toBe(240_000)
    expect(eta(10, 0, 60_000, [], NOW, undefined)).toBeNull()
    expect(eta(10, 10, 60_000, [], NOW, undefined)).toBe(0)
  })

  test('samples older than the window drop off', () => {
    let samples = [{ t: NOW - 3 * WINDOW_MS, done: 0 }]
    samples = addSample(samples, NOW - WINDOW_MS - 1, 1)
    samples = addSample(samples, NOW, 2)
    expect(samples.map(s => s.done)).toEqual([1, 2])
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
      new Map(),
    )
    expect(groups.map(g => g.id)).toEqual(['g2', 'g1'])
    const g1 = groups[1]!
    expect([g1.done, g1.total, g1.state]).toEqual([5, 10, 'running'])
    expect(g1.parts.map(p => p.part)).toEqual(['1 of 2', '2 of 2'])
    expect(groups[0]!.elapsedMs).toBe(8_000)
    expect(groups[0]!.etaMs).toBeNull()
  })

  test('the status line counts what runs, and is cleared when nothing does', () => {
    const groups = buildGroups([{ file: file({ done: 5 }), isAlive: true }], NOW, {}, new Map())
    expect(statusLine(groups)).toBe('1 run · 50% · ~1m left')
    expect(statusLine(buildGroups([{ file: file({ status: 'done', done: 10 }), isAlive: true }], NOW, {}, new Map()))).toBeUndefined()
    expect(duration(72 * 60_000)).toBe('1h12m')
  })

  test('a toast when a group ends, once', () => {
    const [done] = buildGroups([{ file: file({ status: 'done', done: 10 }), isAlive: true }], NOW, {}, new Map())
    expect(endToast(done!, 'running')).toMatch(/done, 10 runs in/)
    expect(endToast(done!, 'done')).toBeUndefined()
    const [dead] = buildGroups([{ file: file({ part: '2/4' }), isAlive: false }], NOW, {}, new Map())
    expect(endToast(dead!, 'running')).toBe('runs (the good bot): a process died (3 of 4)')
  })
})

/** The world beneath the mod: the progress folder, live pids, and what it showed. */
function world(on: On) {
  const files = new Map<string, Record<string, unknown>>()
  const alive = new Set<number>()
  const zombies = new Set<number>()
  const shown = { status: [] as (string | undefined)[], toasts: [] as string[], removed: [] as string[], opened: 0 }
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
    expect(ran.text).toBe('Runs pane opened.')
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
