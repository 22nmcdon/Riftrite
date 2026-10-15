// The run-status mod's logic, with no `$`: reading progress files, each
// part's and group's state, the ETA, and the text the status line, the pane,
// /runs, and the notices show. register.tsx does the reading, the timer and the drawing.

import type { GroupView, JobState, PartView, ProgressFile } from '../types'

/** A part with no progress for this long is stale (longer when its units are slow). */
export const STALE_MS = 60_000
/**
 * No progress for this many units' worth of its pace before a part is stale:
 * one run can take several times the average, and a dead process is caught
 * by its pid, so stale is only for a process that's alive and stuck.
 */
export const STALE_UNITS = 10
/** With no pace to go on yet (no unit done anywhere, no history), stale after this long. */
export const STALE_UNKNOWN_MS = 30 * 60_000
/**
 * How many of the group's units a process's own count as before its own pace
 * outweighs the group's: a few finished units are noise, and the slowest of
 * eight noisy guesses ran hours long early in a run.
 */
export const PACE_PRIOR_UNITS = 6

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
 * process is gone is dead; one with no progress for longer than STALE_UNITS
 * units at its pace (at least STALE_MS; STALE_UNKNOWN_MS with no pace) is
 * stale.
 */
export function partState(file: ProgressFile, isAlive: boolean, now: number, paceMs: number | undefined): JobState {
  if (file.status !== 'running') return file.status
  if (!isAlive) return 'dead'
  const limit = paceMs === undefined ? STALE_UNKNOWN_MS : Math.max(STALE_MS, STALE_UNITS * paceMs)
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

/**
 * One process's ms per unit: its finished units' time blended with the
 * group's pace (`groupMs`, one process's ms per unit over the group, or
 * history's), the group's counting as PACE_PRIOR_UNITS units; undefined with
 * neither.
 */
export function pace(file: ProgressFile, groupMs: number | undefined): number | undefined {
  const own = file.done > 0 ? file.updated_ms - file.started_ms : 0
  if (groupMs === undefined) return file.done > 0 ? own / file.done : undefined
  return (own + PACE_PRIOR_UNITS * groupMs) / (file.done + PACE_PRIOR_UNITS)
}

/** One process's ms left at `paceMs`, less what its unit under way has already taken. */
export function eta(file: ProgressFile, now: number, paceMs: number | undefined): number | null {
  const left = file.total - file.done
  if (left <= 0) return 0
  if (paceMs === undefined) return null
  return Math.max(0, left * paceMs - Math.min(now - file.updated_ms, paceMs))
}

/**
 * The files grouped and measured, newest group first. A group's ETA is its
 * slowest running process's, since the last units wait on the slowest while
 * the rest stand done.
 */
export function buildGroups(seen: Seen[], now: number, history: History): GroupView[] {
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
    // One process's ms per unit over the group's finished units, else history's.
    const doneSoFar = list.reduce((sum, one) => sum + one.file.done, 0)
    const groupMs = doneSoFar > 0
      ? list.reduce((sum, one) => sum + (one.file.done > 0 ? one.file.updated_ms - one.file.started_ms : 0), 0) / doneSoFar
      : groupHistory === undefined ? undefined : groupHistory * partCount
    const paces = list.map(({ file }) => pace(file, groupMs))
    const parts: PartView[] = list.map(({ file, isAlive }, i) => ({
      id: file.id,
      part: partName(file.part),
      total: file.total,
      done: file.done,
      state: partState(file, isAlive, now, paces[i]),
    }))
    const total = list.reduce((sum, one) => sum + one.file.total, 0)
    const done = list.reduce((sum, one) => sum + one.file.done, 0)
    const state = groupState(parts.map(p => p.state))
    const isGoing = parts.some(p => isActive(p.state))
    const startedMs = Math.min(...list.map(one => one.file.started_ms))
    const endedMs = isGoing ? now : Math.max(...list.map(one => one.file.updated_ms))
    const elapsedMs = Math.max(0, endedMs - startedMs)
    let etaMs: number | null = isGoing ? 0 : null
    list.forEach(({ file }, i) => {
      if (etaMs === null || !isActive(parts[i]!.state)) return
      const left = eta(file, now, paces[i])
      etaMs = left === null ? null : Math.max(etaMs, left)
    })
    groups.push({
      id,
      label: first.label,
      kind: first.kind,
      total,
      done,
      state,
      startedMs,
      elapsedMs,
      etaMs,
      parts,
    })
  }
  return groups.sort((a, b) => b.startedMs - a.startedMs)
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

/** One line of a group: label, percent, done of total, elapsed, ETA, and state. */
export function groupLine(group: GroupView): string {
  const left = group.etaMs !== null ? ` · ~${duration(group.etaMs)} left` : isGoing(group) ? ' · ETA unknown' : ''
  return `${group.label}: ${percent(group.done, group.total)}% · ${group.done}/${group.total} ${group.kind} · ${duration(group.elapsedMs)} elapsed${left} · ${group.state}`
}

/** The whole status as text (what /runs answers, for surfaces that draw no pane). */
export function statusText(groups: GroupView[]): string {
  if (groups.length === 0) return 'No runs. The long tools write to .progress/ while they go.'
  const lines: string[] = []
  for (const group of groups) {
    lines.push(groupLine(group))
    lines.push(`  ${bar(group.done, group.total, 30)}`)
    if (group.parts.length > 1) {
      for (const part of group.parts) {
        lines.push(`  ${part.part || part.id}: ${part.done}/${part.total}${part.state === 'running' ? '' : ` ${part.state}`}`)
      }
    }
  }
  return lines.join('\n')
}

/**
 * The quarter a group has reached (0 to 4), for the notices: one at each
 * 25% it passes, so a long run reports a few times, not every poll.
 */
export function quarter(group: GroupView): number {
  return group.total <= 0 ? 4 : Math.min(4, Math.floor((group.done * 4) / group.total))
}

