// The run-status mod's logic, with no `$`: reading progress files, each
// part's and group's state, the ETA, and the text the status line and the
// pane show. register.tsx does the reading, the timer and the drawing.

import type { GroupView, JobState, PartView, ProgressFile } from '../types'

/** A part with no progress for this long is stale (longer when its units are slow). */
export const STALE_MS = 60_000
/** A part's units are this many times slower than usual before it's stale. */
export const STALE_UNITS = 3
/** With no pace to go on yet (no unit done, no history), stale after this long. */
export const STALE_UNKNOWN_MS = 30 * 60_000
/** The ETA's rate comes from samples this recent. */
export const WINDOW_MS = 5 * 60_000
/** A window shorter than this isn't enough to go on. */
export const MIN_WINDOW_MS = 30_000

/** A group's done count at a moment, for the sliding window. */
export type Sample = { t: number; done: number }

/** Wall ms per unit for a whole group, by historyKey. */
export type History = Record<string, number>

/** A file as read, with whether its process still runs (true when unknown). */
export type Seen = { file: ProgressFile; isAlive: boolean }

const STATUSES = ['running', 'done', 'failed'] as const

/** A progress file's contents, or undefined if it isn't one. */
export function parseProgress(name: string, text: string): ProgressFile | undefined {
  let data: unknown
  try {
    data = JSON.parse(text)
  } catch {
    return undefined
  }
  if (typeof data !== 'object' || data === null) return undefined
  const d = data as Record<string, unknown>
  const num = (key: string): number | undefined => (typeof d[key] === 'number' ? (d[key] as number) : undefined)
  const str = (key: string): string => (typeof d[key] === 'string' ? (d[key] as string) : '')
  const total = num('total')
  const done = num('done')
  const started = num('started_ms')
  const updated = num('updated_ms')
  const pid = num('pid')
  const status = STATUSES.find(s => s === d['status'])
  if (total === undefined || done === undefined || started === undefined || updated === undefined || pid === undefined || status === undefined) {
    return undefined
  }
  const id = name.replace(/\.json$/, '')
  return {
    id,
    label: str('label') || id,
    kind: str('kind') || 'units',
    total,
    done,
    started_ms: started,
    updated_ms: updated,
    group: str('group') || id,
    part: str('part'),
    pid,
    status,
  }
}

export function historyKey(kind: string, label: string, parts: number): string {
  return `${kind}|${label}|${parts}`
}

/** "k/N" as "k+1 of N"; "" stays "". */
export function partName(part: string): string {
  const m = /^(\d+)\/(\d+)$/.exec(part)
  return m ? `${Number(m[1]) + 1} of ${m[2]}` : ''
}

/**
 * A part's state. Done and failed come from the file; a running file whose
 * process is gone is dead; one with no progress for longer than its pace
 * allows is stale (at least STALE_MS; STALE_UNITS times its ms per unit, which
 * a run of minutes needs; STALE_UNKNOWN_MS before there's any pace).
 */
export function partState(file: ProgressFile, isAlive: boolean, now: number, partMsPerUnit: number | undefined): JobState {
  if (file.status !== 'running') return file.status
  if (!isAlive) return 'dead'
  const pace = file.done > 0 ? (file.updated_ms - file.started_ms) / file.done : partMsPerUnit
  const limit = pace === undefined ? STALE_UNKNOWN_MS : Math.max(STALE_MS, STALE_UNITS * pace)
  return now - file.updated_ms > limit ? 'stale' : 'running'
}

/** A group's state from its parts': dead, stale, running, failed, then done. */
export function groupState(states: JobState[]): JobState {
  for (const state of ['dead', 'stale', 'running', 'failed'] as const) {
    if (states.includes(state)) return state
  }
  return 'done'
}

export function isActive(state: JobState): boolean {
  return state === 'running' || state === 'stale'
}

/** Whether any of a group's processes still runs (a group with a dead part may). */
export function isGoing(group: GroupView): boolean {
  return group.parts.some(p => isActive(p.state))
}

/** Units per ms over the last WINDOW_MS of samples, or undefined if too little. */
export function windowRate(samples: Sample[], now: number): number | undefined {
  const recent = samples.filter(s => now - s.t <= WINDOW_MS)
  const first = recent[0]
  const last = recent[recent.length - 1]
  if (!first || !last || last.t - first.t < MIN_WINDOW_MS || last.done <= first.done) return undefined
  return (last.done - first.done) / (last.t - first.t)
}

/**
 * Ms left: from the sliding window's rate; before there's enough of it, from
 * history (ms per unit for this kind, label, and part count); then from the
 * rate since the start; else null.
 */
export function eta(total: number, done: number, elapsedMs: number, samples: Sample[], now: number, historyMsPerUnit: number | undefined): number | null {
  const left = total - done
  if (left <= 0) return 0
  const rate = windowRate(samples, now)
  if (rate !== undefined) return left / rate
  if (historyMsPerUnit !== undefined) return left * historyMsPerUnit
  if (done > 0) return left * (elapsedMs / done)
  return null
}

/** The files grouped and measured, newest group first. */
export function buildGroups(seen: Seen[], now: number, history: History, samples: Map<string, Sample[]>): GroupView[] {
  const byGroup = new Map<string, Seen[]>()
  for (const one of seen) {
    const list = byGroup.get(one.file.group) ?? []
    list.push(one)
    byGroup.set(one.file.group, list)
  }
  const groups: GroupView[] = []
  for (const [id, list] of byGroup) {
    list.sort((a, b) => a.file.part.localeCompare(b.file.part, undefined, { numeric: true }) || a.file.id.localeCompare(b.file.id))
    const first = list[0]!.file
    const partCount = list.length
    const groupHistory = history[historyKey(first.kind, first.label, partCount)]
    const partMsPerUnit = groupHistory === undefined ? undefined : groupHistory * partCount
    const parts: PartView[] = list.map(({ file, isAlive }) => ({
      id: file.id,
      part: partName(file.part),
      total: file.total,
      done: file.done,
      state: partState(file, isAlive, now, partMsPerUnit),
    }))
    const total = list.reduce((sum, one) => sum + one.file.total, 0)
    const done = list.reduce((sum, one) => sum + one.file.done, 0)
    const state = groupState(parts.map(p => p.state))
    const isGoing = parts.some(p => isActive(p.state))
    const startedMs = Math.min(...list.map(one => one.file.started_ms))
    const endedMs = isGoing ? now : Math.max(...list.map(one => one.file.updated_ms))
    const elapsedMs = Math.max(0, endedMs - startedMs)
    groups.push({
      id,
      label: first.label,
      kind: first.kind,
      total,
      done,
      state,
      startedMs,
      elapsedMs,
      etaMs: isGoing ? eta(total, done, elapsedMs, samples.get(id) ?? [], now, groupHistory) : null,
      parts,
    })
  }
  return groups.sort((a, b) => b.startedMs - a.startedMs)
}

/** Adds a sample and drops those past the window (one before it kept, so a full window spans it). */
export function addSample(list: Sample[], now: number, done: number): Sample[] {
  const next = [...list, { t: now, done }]
  while (next.length > 2 && now - next[1]!.t >= WINDOW_MS) next.shift()
  return next
}

export function percent(done: number, total: number): number {
  return total <= 0 ? 100 : Math.floor((done * 100) / total)
}

/** "1h12m", "4m", "45s". */
export function duration(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000))
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  if (h > 0) return `${h}h${String(m).padStart(2, '0')}m`
  if (m > 0) return `${m}m`
  return `${s}s`
}

/** "2 runs · 47% · ~1h12m left", or undefined when nothing runs. */
export function statusLine(groups: GroupView[]): string | undefined {
  const active = groups.filter(isGoing)
  if (active.length === 0) return undefined
  const total = active.reduce((sum, g) => sum + g.total, 0)
  const done = active.reduce((sum, g) => sum + g.done, 0)
  const etas = active.map(g => g.etaMs)
  const left = etas.some(e => e === null) ? 'ETA unknown' : `~${duration(Math.max(...(etas as number[])))} left`
  const stale = active.filter(g => g.state === 'stale').length
  const dead = active.filter(g => g.state === 'dead').length
  const words = [`${active.length} ${active.length === 1 ? 'run' : 'runs'}`, `${percent(done, total)}%`, left]
  if (stale > 0) words.push(`${stale} stale`)
  if (dead > 0) words.push(`${dead} dead`)
  return words.join(' · ')
}

/** The toast for a group that has just ended, or undefined if it hasn't. */
export function endToast(group: GroupView, previous: JobState | undefined): string | undefined {
  if (isActive(group.state) || (previous !== undefined && !isActive(previous))) return undefined
  switch (group.state) {
    case 'done':
      return `${group.label}: done, ${group.total} ${group.kind} in ${duration(group.elapsedMs)}`
    case 'failed':
      return `${group.label}: failed (${group.done} of ${group.total} ${group.kind})`
    case 'dead': {
      const dead = group.parts.filter(p => p.state === 'dead').map(p => p.part || p.id)
      return `${group.label}: a process died (${dead.join(', ')})`
    }
  }
  return undefined
}

/** A text bar `width` cells wide. */
export function bar(done: number, total: number, width: number): string {
  const filled = total <= 0 ? width : Math.min(width, Math.floor((done * width) / total))
  return '█'.repeat(filled) + '░'.repeat(width - filled)
}
