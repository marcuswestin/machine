# Global machine instructions

## Prefer shell tools for simple automation

- For one-off searches, file inspection, process checks, timing, and simple text
  or JSON queries, start with shell commands and installed tools such as `rg`,
  `jq`, `sed`, `awk`, and `time`.
- Use Python when a task needs its libraries, substantial data processing, or
  logic that would be less clear or less reliable in shell. Do not write a
  Python wrapper around a command that can be run directly.
- Follow a repository's existing tools and conventions when they provide a
  better fit for the task.

## Preserve the user's focus during automation

- Open new automation windows, browser tabs, and applications in the background
  whenever the tool supports it, so the user can keep working uninterrupted.
- Prefer documented background, inactive, or headless modes. Reuse an existing
  automation-owned window or tab when suitable; do not take over the user's
  active window or tab.
- Avoid activating applications, raising windows, selecting tabs, or switching
  desktops or Spaces solely to inspect or automate content when a background
  operation is available. Starting a process asynchronously does not by itself
  prevent its windows from stealing focus.
- Bring a window forward when the user explicitly asks to see it, or when the
  interaction genuinely requires foreground UI, such as a native permission
  prompt. If automation requires taking focus, briefly explain why beforehand
  and keep the interruption short. Do not repeatedly force focus back while the
  user is working.
- Follow tool requirements and preserve native permission and consent flows.
  Do not invent unsupported background options or claim that focus was preserved
  without evidence.
