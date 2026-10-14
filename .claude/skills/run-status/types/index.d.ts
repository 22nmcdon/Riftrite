// The run-status mod's contract: the progress files tools/progress.gd writes,
// and the groups the mod's pane and status line show.

/** One <repo>/.progress/<id>.json, as tools/progress.gd writes it. */
export type ProgressFile = {
  /** The file's name without `.json`: the tool and its process id. */
  id: string
  label: string
  /** What a unit is: runs, encounters, teams, builds. */
  kind: string
  total: number
  done: number
  /** Wall-clock ms since the epoch. */
  started_ms: number
  updated_ms: number
  /** The processes splitting one job share it (a --jobs parent's id). */
  group: string
  /** "k/N" (k from 0), or "" for a job of one process. */
  part: string
  pid: number
  status: 'running' | 'done' | 'failed'
}

/** running; stale (no progress for too long); dead (its process is gone); done; failed. */
export type JobState = 'running' | 'stale' | 'dead' | 'done' | 'failed'

export type PartView = {
  id: string
  /** "1 of 4", or "" for a job of one process. */
  part: string
  total: number
  done: number
  state: JobState
}

export type GroupView = {
  id: string
  label: string
  kind: string
  total: number
  done: number
  state: JobState
  startedMs: number
  elapsedMs: number
  /** Ms left, or null while there's nothing to go on. */
  etaMs: number | null
  parts: PartView[]
}

declare module 'claude-code' {
  interface PluginState {
    'run-status': { groups: GroupView[] }
  }
}
