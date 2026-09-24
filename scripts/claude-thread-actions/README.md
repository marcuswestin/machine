# Claude thread Pin / Archive hotkeys (prototype)

Sub-second Pin and Archive for the focused Claude Desktop **Code** session via macOS Accessibility.

## Verdict

|                                | Feasible &lt;1s? | Notes                                            |
| ------------------------------ | ---------------- | ------------------------------------------------ |
| **Pin** (UI Pin ↔ `isStarred`) | **Yes**          | AX press `Pin` / `Unpin` on sidebar session menu |
| **Archive**                    | **Yes**          | AX press `Archive` on the same menu              |

No public URL/menu/IPC for outside callers. Host MCP (`ccd_sidebar.set_pinned`, `ccd_session_mgmt.archive_session`) and Electron IPC (`LocalSessions_$_updateSession` / `$_archive`) exist but are in-process only.

## Mechanism (best)

1. Set `AXEnhancedUserInterface` so Chromium exposes the sidebar tree.
2. Resolve current session = max `lastFocusedAt` among non-archived `~/Library/Application Support/Claude/claude-code-sessions/**/*.json`.
3. Find sidebar `AXPopUpButton` **More options for &lt;title&gt;** (not the main-pane twin — that menu has no Pin).
4. Hover + `AXPress` → menu with `Pin`/`Unpin` and `Archive`.
5. `AXPress` the target item.

## Measured latency (this machine)

Compiled binary, dry-run (open menu → list → Escape), Claude already running:

|                          | Warm run                                    |
| ------------------------ | ------------------------------------------- |
| Discover session         | ~45 ms                                      |
| Find sidebar control     | ~210 ms                                     |
| Menu visible after press | ~60–130 ms                                  |
| **Total dry-run**        | **~340–370 ms** (first run can be ~700 ms+) |

Execute (`--pin` / `--archive`) should be similar or slightly faster (press item instead of Escape). Hard requirement (&lt;1 s) met; &lt;300 ms ideal is close on a warm compiled path.

## Permissions

- **Accessibility** for the binary (or Terminal/`swift`) that runs this.
- Mouse hover uses `CGEvent`; if hover fails, grant **Input Monitoring** too (or rely on Accessibility alone after a retry).

## Usage

```sh
# Safe default — no mutation
swift scripts/claude-thread-actions/claude-thread-actions.swift --dry-run

# Prefer compiled (lower cold-start; grant AX to this binary)
swiftc -O -o /tmp/claude-thread-actions \
  scripts/claude-thread-actions/claude-thread-actions.swift
/tmp/claude-thread-actions --dry-run

# Mutates — only when you intend to
/tmp/claude-thread-actions --pin
/tmp/claude-thread-actions --unpin
/tmp/claude-thread-actions --archive
```

## Bind shortcuts

Raycast Script Command or Karabiner `shell_command` → compiled binary with `--pin` / `--archive`.

## Fragility

- Needs Code sidebar visible and the session row in the AX tree (scrolled into view).
- Must target **sidebar** More options, not the session header menu.
- Claude UI/AX labels can change across Desktop updates.
- `lastFocusedAt` must match the on-screen title.
