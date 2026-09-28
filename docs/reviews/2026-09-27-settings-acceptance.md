# Configuration transfer: implementation and acceptance — 2026-09-27

This follows the [configuration review](2026-09-26-configuration-sync.md). Changes
are prepared in this worktree; they still need committing/transferring before
another Mac can apply them. The unrelated zshrc edit is untouched.

## Additional gaps addressed

| Surface          | Implementation                                                                                                                                                                                                                                        | Local validation                                                                                                                                                                          |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Weather          | The guided full apply asks for a native Menu Bar check. The UI script was removed after it failed to find the Weather control despite the item being visible and iTerm having the required permissions.                                               | The checkbox was visible and enabled in System Settings on September 28. No privacy permissions were changed.                                                                             |
| Claude Desktop   | `config/app-preferences.json` declares English, system theme, current UI zoom, quick-entry shortcut, branch prefix, dock bounce and keep-awake preferences. A recursive merge preserves every undeclared field.                                       | Live declared subset matches. Fixture tests cover preservation, idempotency, running-app refusal, missing files, malformed JSON and symlinks.                                             |
| Antigravity IDE  | Its separate `User/settings.json` is now chezmoi-managed, retaining the current `explorer.confirmDelete = false`. Included in drift review.                                                                                                           | Existing live content inspected; symlink installation waits for apply.                                                                                                                    |
| iTerm2           | Machine Dynamic Profile includes explicit light/dark colors, fonts, spacing and other visual options from this Mac. Stable GUID declared as default; existing profiles stay intact. Selected global appearance/keyboard preferences are also tracked. | JSON/Nix validation; startup source restores a dynamic profile's original default GUID after loading it. Verify a new window after relaunch.                                              |
| Chrome           | The repo declares iCloud Passwords and the guided full apply links to its Chrome Web Store page for native installation.                                                                                                                              | macOS denies writes to Chrome's protected profile; no direct profile write or permission bypass is attempted.                                                                             |
| Raycast          | Refreshed from the user's Desktop native export, keeping portable preferences/default-extension settings only. Export lists zero installed/local extensions.                                                                                          | Gzip/JSON inspected. Account, installation IDs, search recency, chats, clipboard, snippets, quicklinks and other personal content were not promoted. Import remains native and confirmed. |
| ChatGPT launcher | Track both current `ChatGPTHelper` shortcuts: Option–Command–Space and Control–Option–Command–Space. Legacy app defaults remain for the legacy installation.                                                                                          | Compared with live helper values; Nix evaluation. This does not declare every current ChatGPT GUI setting.                                                                                |
| Docker           | A denied settings write now fails apply instead of silently succeeding. Report labels denied reads separately from invalid JSON.                                                                                                                      | Live Group Container access is still denied. No permission grants or private-file workaround performed.                                                                                   |
| Drift checks     | Include Claude's allowlisted leaves, Antigravity IDE, the declared Chrome extension in browser inventory review, and both import confirmations. Weather is a manual UI check. Normalize targets through XML just as exported defaults are parsed.     | Avoids the false Return/newline shortcut mismatch caused by XML normalization. Reports do not print private values.                                                                       |

The Claude zoom value `1.0954451150103321` is the current app's stored scale factor.
iTerm color components are exported sRGB values in the app's native profile schema;
its font fields combine font name and point size. Raycast's `Command-49` is
Command–Space (macOS virtual key 49), `macos` is its native navigation style,
`squareBrackets` selects bracket-key page navigation, and the exported numeric
escape/window/API selectors retain the app's native values. Do not treat the
Raycast file as a full personal-data backup.

## Verify in one pass

Run **`just apply-full`** from Terminal.app. It guides the steps below in the
CLI, including numbered native-import instructions and Enter-to-continue prompts.
The detailed checklist remains here as a reference; no need to run each command
separately when using the guided recipe.

1. Save work. The command lists only apps with changed managed settings and
   warns before gracefully quitting those that are running. Use Terminal.app if
   the plan includes your current terminal. Apps such as ChatGPT/Codex or
   Docker Desktop are restarted only when their settings require it. Active
   Codex tasks and Docker containers may be interrupted; choose
   an appropriate time before pressing Enter.
2. The wrapper runs `just apply`. If Docker's Group Container is denied, use a Terminal that
   already has appropriate access or grant that Terminal access in System Settings,
   then rerun. No script will grant privacy permissions for you.
3. Complete the revised **Raycast import** and **Thaw import AND apply** prompts.
   Raycast's full native preview lets you inspect the categories before importing.
   Cancel leaves the respective confirmation pending.
4. The command restarts previously running apps and startup apps in the background.
   In Chrome's Default profile, install iCloud Passwords from the linked Chrome
   Web Store page if missing. Confirm it in `chrome://extensions` and approve
   native prompts yourself. Firefox/Safari have no declared extensions to add.
5. Run **`just settings-check`**. It prints saved settings/import checks and
   reminds you to verify Weather in System Settings.
6. Check this visible-result list on each Mac:

   - [ ] **Stats:** GPU → Network → Disk → Sensors → RAM → CPU → Battery in one group.
   - [ ] **CodexBar:** one branded percentage item; providers enabled. Highest-usage
         selection may choose a different icon when account usage differs.
   - [ ] **Thaw:** Handy, ChatGPT/Codex and Cursor hidden after its rehide interval;
         Sound, Weather and the combined Stats group positioned as desired. Adjust
         display associations and re-export with `just export-thaw` if needed.
   - [ ] **Weather:** visible and showing the intended first location. Choosing the
         city/current location and granting location access remain local tasks.
   - [ ] **Sound:** visible; choose the actual audio output for this Mac.
   - [ ] **Raycast:** expected hotkey, appearance and navigation; import confirmed.
   - [ ] **Claude:** system theme, English, expected zoom and Ctrl–Cmd–Space quick entry.
   - [ ] **Antigravity IDE:** intended explorer delete-confirmation setting loaded.
   - [ ] **iTerm2:** a new window uses the Machine profile and expected colors/fonts.
   - [ ] **Chrome:** iCloud Passwords enabled and working after native approval.
   - [ ] **ChatGPT/Codex:** launcher shortcuts work after restarting the app/helper.
         In Settings > Keyboard Shortcuts > Number shortcuts, choose **Chats**;
         Command-1–9 then selects chats and Option-Command-1–9 selects tabs.
         The repository declares this in `config/codex/config.toml` and merges
         the managed key into writable `~/.codex/config.toml`. A conflicting
         local value stops apply for review with `just save-machine-settings`.
   - [ ] **Docker:** declared settings read back successfully after restart.

No full computer restart is expected. A running app's cached state is not proof of
saved preferences, and a successful report command does not mean every row matches.

Focused validation passed: three Bun tests (16 assertions), Nix evaluation, chezmoi rendering/diff for
new targets, shell syntax, recipe dry-run, formatting, and whitespace checks.
The live settings report identifies pending iTerm default selection, Stats,
CodexBar, Chrome's install file, and native import confirmations; Docker remains
explicitly unverified. The Claude subset and current ChatGPT shortcuts match.
No full `just apply`, app shutdown, reboot, commit or push was performed here.

## Boundaries that remain

These are not portable configuration imports: account sign-in, OAuth tokens,
permission grants, browser bookmarks/history, device IDs, cloud sync, project or
session state, and per-display associations. Neither setup nor review should
claim they are synchronized.

Firefox's profile directory remains unreadable here; its preferences are **unknown**.
LM Studio has no configuration at the inspected conventional paths. No selected
portable Xcode/Zoom preference keys were present, and Spotify's inspected prefs
contained credentials/runtime state rather than a chosen portable UI subset.
These findings do not justify inventing settings or copying entire app databases.
Their installation is managed; any additional customization needs an explicit
desired setting and accessible evidence.

## Sources

- [Apple UI scripting and consent](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html)
- [Apple Weather menu control and first location](https://support.apple.com/en-ie/guide/weather-mac/apdwb2768d6e/mac)
- [Chrome external installation and user confirmation](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions)
- [iTerm Dynamic Profiles](https://iterm2.com/documentation-dynamic-profiles.html)
- [iTerm startup default-profile restoration](https://github.com/gnachman/iTerm2/blob/master/sources/Settings/Profiles/ITAddressBookMgr.m)
- [Raycast native import/export](https://manual.raycast.com/import-export) (installed export inspected from Raycast 1.104.29; current documentation also covers newer formats)
