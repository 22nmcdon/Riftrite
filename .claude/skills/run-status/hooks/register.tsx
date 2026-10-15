// Run status: shows the long tools' progress files (tools/progress.gd writes
// <repo>/.progress/<id>.json) while they run, as a status line, a pane of one
// card per group (a bar per process), and a toast when a group ends.
// /runs opens the pane; /runs clear deletes the files of finished, failed,
// and dead jobs. No model calls. The logic is in model.ts.

import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { GroupView, JobState } from '../types'
import {
  bar,
  buildGroups,
  duration,
  endToast,
  groupLine,
  historyKey,
  isGoing,
  parseProgress,
  percent,
  quarter,
  statusLine,
  statusText,
  type History,
  type Seen,
} from './model'

const PANE = 'run-status'
const POLL_MS = 2000
const HISTORY = 'history'
const groupsAtom = atom({ plugin: 'run-status', key: 'groups' } as const, [] as GroupView[])

const STATE_COLOR: Record<string, string> = {
  running: 'suggestion',
  stale: 'warning',
  dead: 'error',
  failed: 'error',
  done: 'success',
}

// The module's own memory (a reload starts it over): the states last seen
// (for toasts), and whether a poll ran.
const lastState = new Map<string, JobState>()
let hasPolled = false
let isPolling = false
const lastQuarter = new Map<string, number>()

// A line in the conversation every client shows (the remote ones draw no
// pane or status line), never read by the model.
async function announce($: Engine, text: string): Promise<void> {
  await $.session.append({ message: { type: 'system', content: [{ type: 'text', text: `run-status: ${text}` }] } }).catch(() => undefined)
}

async function progressDir($: Engine): Promise<string> {
  const custom = await $.env.get('RIFTRITE_PROGRESS_DIR')
  return custom || `${await $.session.root()}/.progress`
}

// Alive unless ps finds no such process or a zombie (one that exited and
// hasn't been reaped, which `kill -0` would call alive).
async function isAlive($: Engine, pid: number): Promise<boolean> {
  try {
    const { exitCode, stdout } = await $.process.run(['ps', '-o', 'stat=', '-p', String(pid)], { timeoutMs: 5000 })
    return exitCode === 0 && !stdout.trim().startsWith('Z')
  } catch {
    return true // couldn't ask: not called dead
  }
}

async function readFiles($: Engine): Promise<Seen[]> {
  const dir = await progressDir($)
  if (!(await $.fs.exists(dir))) return []
  const seen: Seen[] = []
  for (const entry of await $.fs.list(dir)) {
    if (entry.kind !== 'file' || !entry.name.endsWith('.json')) continue
    const text = await $.fs.read(`${dir}/${entry.name}`).catch(() => undefined)
    const file = text === undefined ? undefined : parseProgress(entry.name, text)
    if (file === undefined) continue
    seen.push({ file, isAlive: file.status === 'running' ? await isAlive($, file.pid) : true })
  }
  return seen
}

async function poll($: Engine): Promise<GroupView[]> {
  if (isPolling) return read($, groupsAtom)
  isPolling = true
  try {
    const now = await $.clock.now()
    const history = ((await $.store.get(HISTORY)) ?? {}) as History
    const seen = await readFiles($)
    const groups = buildGroups(seen, now, history)
    let learned = false
    for (const group of groups) {
      const toast = hasPolled ? endToast(group, lastState.get(group.id)) : undefined
      const reached = quarter(group)
      const before = lastQuarter.get(group.id)
      if (hasPolled && toast === undefined && isGoing(group) && (before === undefined || reached > before)) {
        await announce($, groupLine(group))
      }
      lastQuarter.set(group.id, reached)
      if (toast !== undefined) {
        $.ui.toast(toast, { timeoutMs: 8000 })
        await announce($, toast)
        if (group.state === 'done' && group.total > 0) {
          history[historyKey(group.kind, group.label, group.parts.length)] = group.elapsedMs / group.total
          learned = true
        }
      }
      lastState.set(group.id, group.state)
    }
    if (learned) await $.store.set(HISTORY, history)
    hasPolled = true
    await update($, groupsAtom, () => groups)
    $.ui.status(statusLine(groups))
    return groups
  } finally {
    isPolling = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'runs',
      description: 'Show the long tool runs (run_runner, sim_runner, placement) and their progress',
      argumentHint: '[clear]',
    })
    $.clock.every(POLL_MS, () => {
      void poll($).catch(() => undefined)
    })
    const groups = await poll($).catch(() => [] as GroupView[])
    await announce($, `watching .progress/: ${statusLine(groups) ?? 'nothing running'}`)
    return next(e)
  })

  on('command.run', { command: 'runs' }, async ($, e) => {
    if ((e.args ?? '').trim() === 'clear') {
      const dir = await progressDir($)
      const groups = await poll($)
      const gone = groups.flatMap(g => g.parts.filter(p => p.state === 'done' || p.state === 'failed' || p.state === 'dead'))
      for (const part of gone) {
        await $.process.run(['rm', '-f', `${dir}/${part.id}.json`]).catch(() => undefined)
      }
      await poll($)
      return { text: gone.length === 0 ? 'No finished, failed, or dead runs to clear.' : `Cleared ${gone.length} progress file${gone.length === 1 ? '' : 's'}.` }
    }
    await poll($)
    const groups = await poll($).catch(() => [] as GroupView[])
    await $.ui.open({ id: PANE, title: 'Runs' })
    return { text: statusText(groups) }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const groups = await read($, groupsAtom)
    const width = Math.max(10, Math.min(48, (e.viewport?.columns ?? 60) - 14))
    return (
      <Box flexDirection="column" gap={1}>
        {groups.length === 0 && <Text dimColor>No runs. The long tools write to .progress/ while they go.</Text>}
        {groups.map(group => (
          <Box key={group.id} flexDirection="column">
            <Box flexDirection="row" justifyContent="space-between">
              <Text bold>{group.label}</Text>
              <Text color={STATE_COLOR[group.state]}>{group.state}</Text>
            </Box>
            <Text>
              {bar(group.done, group.total, width)} {percent(group.done, group.total)}%
            </Text>
            <Text dimColor>
              {group.done}/{group.total} {group.kind} · {duration(group.elapsedMs)} elapsed
              {group.etaMs !== null ? ` · ~${duration(group.etaMs)} left` : group.state === 'running' ? ' · ETA unknown' : ''}
            </Text>
            {group.parts.length > 1 &&
              group.parts.map(part => (
                <Text key={part.id} color={part.state === 'running' || part.state === 'done' ? undefined : STATE_COLOR[part.state]} dimColor={part.state === 'done'}>
                  {(part.part || part.id).padStart(7)} {bar(part.done, part.total, Math.max(6, Math.floor(width / 2)))} {part.done}/{part.total}
                  {part.state === 'running' ? '' : ` ${part.state}`}
                </Text>
              ))}
          </Box>
        ))}
      </Box>
    )
  })
}
