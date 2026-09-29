---
name: commit-all-chunks
description: Commit every outstanding Git change in small, self-contained chunks when the Developer explicitly asks to commit all outstanding changes. Do not use for a routine single-change commit.
---

# Commit All Chunks

Use this workflow only after the Developer explicitly asks to commit all current uncommitted changes. This request authorizes commits only, not edits or a push.

1. Inspect `git status`, staged and unstaged diffs, and untracked files. Do not change file contents. If preparation reveals something that needs a fix, ask before making that fix.
2. If anything is staged, unstage it without changing the working tree. Choose the smallest self-contained remaining chunk, stage only that chunk, review the staged diff, and commit it. Repeat until every current uncommitted change is accounted for. Use patch staging when a file contains separate chunks.
3. Give each commit a concise one-line summary, a blank line, then one bullet per line describing the chunk. Put no blank lines between bullets.
4. Do not rerun full tests or validation between commits unless a command changed files after the validated state. Do not run formatters or other file-writing preparation commands. If a hook changes files, stop and ask before fixing or proceeding.
5. Finish with a clean `git status`, or report exactly which changes could not be committed and why. Do not push unless separately requested.
