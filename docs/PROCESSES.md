# Processes, ports and external state

This document owns the rules for anything an agent starts, connects to or
waits on: datastores, ports, processes, background tasks, waits, and long
batch work. `AGENTS.md` §"Processes, ports and external state" says when it
is read; the area files say what is started for their stack and how.

- **(MUST)** Only ever connect to a datastore you started yourself in this
  session, or one the user named as yours to use *in this conversation*.
  The default local port is the right address for the test suites — but
  only once *you* brought that datastore up. Anything else that is already
  listening is never yours to use, however plausible the port, the database
  name, or an environment variable makes it look: the user may have a
  **production** datastore forwarded to a local port for analysis, and a test
  run against that is a serious incident, not an inconvenience. So if
  something already answers where you meant to start your own, stop and ask —
  do not connect, do not "just read", and never kill or restart what is
  there. This covers every command that opens a connection, and it is not
  satisfied by an inference from a previous session, from your own memory,
  or from a permission given in an earlier conversation.
- **(MUST)** Roll a random port for anything you start, never the default.
  Several sessions run in parallel in their own worktrees, and on a fixed
  port they collide: the second one either fails to start or — the case that
  actually costs something — reaches an instance that is not its own. Test
  configurations read the port from the environment for exactly this; pick a
  free high port, publish the container on it, and pass it to every command
  in that run. The one exception is something that only works on a fixed
  port — a registered callback URL, a licence bound to a port — and there
  you check that the port is free, start, and say in the same message that
  you took a fixed one.
- **(MUST)** Shut down what you started once the run that needed it is over,
  and remove its container. It is yours for that run only: left behind, it is
  indistinguishable from the "something is already listening" the rule above
  tells the next session to stop at — so an abandoned container does not just
  leak a port, it blocks the next run. This holds when the tests fail and when
  the work is abandoned halfway.
- **(MUST NOT)** Start the user's *interactive* dev server, watcher or REPL.
  That one is theirs: it owns their terminal, their port and their reload
  key, and a second one competing with it is a nuisance they have to notice
  and kill. An agent's own instance is a different thing and is allowed under
  four conditions that together make it invisible to the user's workflow: it
  runs **non-interactively**, on **its own rolled port**, as a **harness
  background task** so the harness can list and kill it, and it is **shut
  down when the run that needed it ends** — including when that run fails or
  is abandoned halfway.
- **(MUST)** Anything that keeps running after the command returns is started
  as a harness background task, never detached by hand with `nohup`, `&`,
  `disown`, `screen` or `tmux`. The harness lists a background task, shows
  its output and lets the user kill it; a hand-detached process is invisible
  to them and outlives the session that started it. If a process genuinely
  cannot run as a task, say so and name its pid and its output paths in the
  same message that starts it.
- **(MUST)** Every wait for a condition carries a deadline, and says so when it
  expires. An unbounded `until … do sleep … done` is the single most expensive
  shape there is: whatever it waits for may have failed *before* the loop
  started, and the loop then spins in silence for as long as anyone lets it. A
  wait that ends in "TIMEOUT after N s" plus the last lines of the log it was
  waiting on turns half an hour of nothing into one legible failure.
- **(MUST)** A command that starts something and then waits on it checks that
  the start succeeded. Backgrounding a process with `&` and redirecting its
  output to a file discards both its exit code and its error message; the
  wait that follows is then waiting on something that is already dead.
- **(MUST NOT)** Start a second background task whose only job is to wait for
  the first. The harness reports a task's completion on its own, so the waiter
  adds no information — it only doubles what the user sees running and makes
  a stalled job look like two stalled jobs. Poll once, deliberately, when
  there is a reason to look before the notification arrives.
- **(MUST)** A long-running run of the agent's own — a sweep, a fetch, a
  measurement — checkpoints what it has collected, exactly as a product job
  does (`docs/ARCHITECTURE_PRINCIPLES.md` §"Derived state").
- **(MUST)** Long batch work — a sweep over hundreds or thousands of items,
  a research pass, a mass edit — runs as a resumable procedure with a
  written protocol, never as a freehand session. The procedure owns batch
  selection, applying results, marking the unresolvable, and the pacing; the
  batch itself never commits. The procedure lives where
  `docs/RULE_WRITING.md` §"Where a rule goes" puts it: a skill file, with
  the plan that explains it under `plans/`.
