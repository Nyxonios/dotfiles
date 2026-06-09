---
name: tmux-bg-tasks
description: >
  Spawn and manage background tasks inside a dedicated tmux session.
  Creates a clearly named tmux session (e.g. 'pi-agent-bg') with multiple
  panes for concurrent long-running commands, local HTTP servers, Kubernetes
  port-forwards, and SSH tunnels. Use whenever you need to run processes
  that should outlive a single turn, monitor them later, capture their output
  asynchronously, avoid blocking the chat loop, or expose a service/port that
  you will query in subsequent steps.
license: MIT
---

# Skill: tmux-bg-tasks

Use tmux to run background tasks in a dedicated, easily identifiable session.

**Arguments:** `$ARGUMENTS` — e.g. a command to run in the background, a window
name, or a natural-language request like "start a build watcher and a test runner
in separate panes"

## Why Tmux?

The `bash` tool blocks until the command finishes. Long-running processes
(builds, downloads, servers, file watchers, simulations) will freeze the agent
until they complete. By sending them to tmux panes, they run in the background
and you can inspect output on subsequent turns.

## Helper Script

Most operations are wrapped in `scripts/pi-tmux.sh`. It stores the active session
name in `/tmp/.pi_agent_tmux_session` so you do not need to pass it every time.

Run `chmod +x scripts/pi-tmux.sh` if needed.

**Direct execution:**
```bash
./scripts/pi-tmux.sh init
./scripts/pi-tmux.sh run main.0 "make"
```

**Sourced as a library:**
```bash
source ./scripts/pi-tmux.sh
pi_tmux init
pi_tmux run main.0 "make"
```

When sourced, all helper functions (e.g. `get_session`) are available in the
current shell. The entrypoint function is named `pi_tmux`.

## Session Naming Convention

- **Default:** `pi-agent-bg`
- **Collision handling:** if `pi-agent-bg` already exists, the helper auto-appends
  a short random suffix (e.g. `pi-agent-bg-a3f1`). The exact name is saved to the
  state file listed above.
- **Identification:** all sessions created by this skill start with `pi-agent-bg`.
  You (or the user) can identify them with `tmux ls | grep pi-agent-bg`.

## Typical Workflow

```bash
# 1. Create the session (detached)
./scripts/pi-tmux.sh init

# 2. (Optional) Create named windows for different task groups
./scripts/pi-tmux.sh window build
./scripts/pi-tmux.sh window tests

# 3. Split a window into additional panes if you need concurrency
./scripts/pi-tmux.sh split build -h
./scripts/pi-tmux.sh split tests -v

# 4. Send commands to specific panes (always append Enter so they execute)
./scripts/pi-tmux.sh run build.0  "make -j$(nproc)"
./scripts/pi-tmux.sh run tests.0  "npm test -- --watch"

# 5. Check output later
./scripts/pi-tmux.sh capture build.0

# 6. Inspect all panes / running commands
./scripts/pi-tmux.sh list

# 7. Clean up when done
./scripts/pi-tmux.sh kill
```

## Raw Tmux Commands (no helper script)

If you prefer or the script is unavailable, use these commands directly.
Use the session name returned by `get_session` (or default to `pi-agent-bg`).

### Create Session
```bash
SESSION="pi-agent-bg"
tmux new-session -d -s "$SESSION" -n "main"
```

### Create a Window
```bash
tmux new-window -t "$SESSION" -n "build"
```

### Split Window into Panes
```bash
tmux split-window -t "$SESSION:build" -d -h   # horizontal split
tmux split-window -t "$SESSION:build" -d -v   # vertical split
```

### Send a Command to a Pane
```bash
tmux send-keys -t "$SESSION:build.0" "cargo build --release" Enter
```

### Capture Pane Output
```bash
# Capture visible area
tmux capture-pane -t "$SESSION:build.0" -p

# Capture full scrollback history (if supported)
tmux capture-pane -t "$SESSION:build.0" -pS -
```

### List Panes with Metadata
```bash
# All panes within the session
tmux list-panes -s -t "$SESSION" -F '#{window_index}.#{pane_index}  wname=#{window_name}  cmd=[#{pane_current_command}]  title=#{pane_title}  pid=#{pane_pid}'

# Just the current window
tmux list-panes -t "$SESSION" -F '#{pane_index}  cmd=[#{pane_current_command}]  pid=#{pane_pid}'
```

### Kill Session
```bash
tmux kill-session -t "$SESSION"
```

## Target Syntax Reference

Targets for `tmux send-keys`, `capture-pane`, `split-window`, etc.:

| Target | Meaning |
|--------|---------|
| `pi-agent-bg` | Session default window, default pane |
| `pi-agent-bg:0` | Session, window index 0 |
| `pi-agent-bg:build` | Session, window named "build" |
| `pi-agent-bg:build.1` | Session, window "build", pane index 1 |
| `build.1` (inside same session) | Window "build", pane index 1 |

## Important Rules

- **Always append `Enter`** when using `tmux send-keys`, otherwise the command
  sits at the shell prompt without executing.
- **Do not attach** if the user did not explicitly ask for it. Attaching steals
  the terminal and can break the agent's execution flow.
- **Capture output** after a reasonable delay (e.g. if the user asks for build
  output, first run the build, then capture after a few seconds or when you know
  it has produced output).
- **Kill the session** when the background work is fully complete to avoid
  leaving orphan tmux servers on the user's machine.
- If you want the output to persist across turns, store it with:
  ```bash
  ./scripts/pi-tmux.sh capture build.0 > /tmp/pi_bg_output.txt
  ```

## HTTP Servers & Services

A common agent task is to start a local HTTP server (e.g. a dev server, mock
API, or static file server) and then query it with `curl`, `web_search`, or
`fetch_content`. Because `bash` blocks, the server must run in a tmux pane.

### Pattern: Start → Wait → Query → Kill

```bash
# 1. Create session
./scripts/pi-tmux.sh init
./scripts/pi-tmux.sh window server

# 2. Start the server in a pane
./scripts/pi-tmux.sh run server.0 "python3 -m http.server 8080 --directory ./site"

# 3. Wait for the port to be open (helper script does this)
./scripts/pi-tmux.sh wait-port 127.0.0.1 8080 15

# 4. Query the server
./scripts/pi-tmux.sh capture server.0
curl -s http://127.0.0.1:8080/ | head -20

# 5. Stop everything when done
./scripts/pi-tmux.sh kill
```

### Useful Server Snippets

| Stack | Command |
|-------|---------|
| Python | `python3 -m http.server 8080` |
| Node | `npx serve -l 8080 dist` |
| PHP | `php -S 127.0.0.1:8080` |
| Go | `go run ./cmd/server` (ensure it binds to 127.0.0.1:8080) |

If a framework captures the terminal (e.g. React dev server with interactive
overlay), redirect `stdin` from `/dev/null` or pass `--no-interactive` flags
when possible:

```bash
./scripts/pi-tmux.sh run server.0 "npm run dev -- --host 127.0.0.1 --port 8080 > /tmp/server.log 2>&1"
# capture from the log file instead of the pane
./scripts/pi-tmux.sh capture server.0
cat /tmp/server.log
```

### Checking Server Health

The helper script can poll an HTTP endpoint:

```bash
./scripts/pi-tmux.sh run server.0 "node server.js"
./scripts/pi-tmux.sh health http://127.0.0.1:8080/healthz 30
curl -s http://127.0.0.1:8080/api/status
```

If `curl` or `nc` are unavailable, use a raw bash loop:

```bash
for i in {1..30}; do nc -z 127.0.0.1 8080 && break; sleep 1; done
```

## Port Forwarding (Kubernetes / SSH)

`kubectl port-forward` and `ssh -L` block until the connection is broken. Run
them in a tmux pane so the forwarded port stays alive while the agent queries
it over multiple turns.

### Kubernetes Port Forward

```bash
# 1. Create the session
./scripts/pi-tmux.sh init
./scripts/pi-tmux.sh window k8s

# 2. Start port-forward in a pane
./scripts/pi-tmux.sh run k8s.0 "kubectl port-forward svc/my-service 8080:80 -n my-namespace"

# 3. Wait for local port to be bound
./scripts/pi-tmux.sh wait-port 127.0.0.1 8080 30

# 4. Query the forwarded service
./scripts/pi-tmux.sh capture k8s.0
curl -s http://127.0.0.1:8080/api/endpoint

# 5. Kill the session (and the port-forward) when done
./scripts/pi-tmux.sh kill
```

**Notes:**
- `kubectl port-forward` prints connection logs; capturing the pane shows which
  pods it selected.
- If the pod restarts, the port-forward dies. Check the pane output before each
  new query and restart if you see "error: lost connection to pod".

### SSH Port Forward

```bash
./scripts/pi-tmux.sh run tunnel.0 "ssh -N -L 8080:internal-db:5432 user@bastion-host"
./scripts/pi-tmux.sh wait-port 127.0.0.1 8080 15
psql -h 127.0.0.1 -p 8080 -U dbuser -c "SELECT 1"
```

## Example: Persistent Build + Test Watch

```bash
# Create session and windows
./scripts/pi-tmux.sh init
./scripts/pi-tmux.sh window build
./scripts/pi-tmux.sh window tests

# Start build in pane 0, test watch in pane 1
./scripts/pi-tmux.sh run build.0  "make"
./scripts/pi-tmux.sh run tests.0  "npm run test:watch"

# Later: check if build finished
./scripts/pi-tmux.sh capture build.0

# Later: check latest test results
./scripts/pi-tmux.sh capture tests.0

# When done
./scripts/pi-tmux.sh kill
```
