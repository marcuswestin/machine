# Application configuration transfer review — 2026-09-26

Follow-up implementation and the consolidated verification steps are in the
[2026-09-27 acceptance checklist](2026-09-27-settings-acceptance.md). The findings
below record the original audit, before those additional changes.

## Scope and conclusion

The repo installs more applications than it configures. A successful apply, an
inventory snapshot, or a saved Thaw profile does not prove that another Mac has
the same appearance, enabled menu controls, permissions, or active layout.

Reviewed all 25 declared casks, custom defaults, chezmoi targets, settings imports,
and relevant local preferences. Discovery found 25 unique matching defaults
domains and 73 unique candidate file paths (28/85 matches before deduplication).
These are candidates, not 73 missing configurations: many contain private or
transient state. Discovery is heuristic and depth-limited; protected paths and
undiscovered containers remain unknown. No access to the other Mac was available.
This review concerns configuration transfer, not package security advisories.

## Changes prepared

| Surface                   | Evidence and change                                                                                                                                                                                                           | Acceptance still needed                                                                                                                      |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| CodexBar                  | No appearance declaration existed. Added the local percent-with-brand-icon display, merged item, highest-usage selection, used-usage bars, absolute reset times, stacked accounts, and cost display preferences.              | Quit before apply and reopen. Highest usage and account availability can legitimately select different provider icons on different Macs.     |
| CodexBar providers        | Track the currently enabled Codex, Claude, Cursor, Gemini, and Antigravity providers. Apply uses the public CLI and changes only enable/disable toggles.                                                                      | Authenticate accounts separately; credentials and private config remain local.                                                               |
| Thaw hidden apps          | The export had individual hidden items for Handy, ChatGPT/Codex, and Cursor but no bundle-level hidden pins. Added those pins so replacement items from these apps retain their intended section.                             | Import and apply the revised profile through Thaw. Verify after auto-rehide; a revealed hidden section is temporarily visible by design.     |
| Thaw new-item placement   | Its anchor contained AeroSpace workspace text. Use the visible section's default placement, independent of that changing title.                                                                                               | Existing ordering still needs visual verification on the other display.                                                                      |
| Sound                     | No declaration enabled the menu control. Added nix-darwin `controlcenter.Sound = true`.                                                                                                                                       | Verify after apply; select the audio output locally. Device routing is not portable configuration.                                           |
| Stats (preceding request) | One combined item with internal order GPU → Network → Disk → Sensors → RAM → CPU → Battery.                                                                                                                                   | Restart Stats after apply; place the combined item in Thaw and re-export. Hardware-unavailable modules may be omitted.                       |
| Raycast imports           | The script stamped success immediately after opening an export. It now stamps only after confirmation of native import completion.                                                                                            | Complete the import when prompted. Confirmation is still not a live comparison of Raycast state. Older opening-only stamps are not accepted. |
| Drift reporting           | Added `just settings-check`; expanded `diff-tracked` to all declared custom user-defaults domains plus CodexBar providers. Discovery reports unreadable directories and handles plist Data/date values when enumerating keys. | A report-only command can succeed while reporting drift. It does not verify live UI or undeclared settings.                                  |

## Remaining configuration coverage

“Managed” means the named subset is declared, not that every app setting is copied
or that the other Mac has loaded it. Related casks are grouped below.

| Application / declaration           | Managed subset                                                             | Missing, local, or unverified                                                                                                                                                                                                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AeroSpace                           | Main configuration, rules, menu display style                              | Runtime workspace contents/window positions are local. Thaw placement can contain changing workspace titles.                                                                                                                                                                         |
| Stats                               | Module selection, widget appearance, combined order                        | Display-specific placement needs Thaw acceptance. Pairing, credentials, updater/window state stay local.                                                                                                                                                                             |
| Thaw                                | General/appearance defaults and native profile export                      | Display UUID associations differ across Macs. Seven old generic Stats item identifiers remain in the export. A confirmation hash does not measure current layout. Permissions remain manual.                                                                                         |
| CodexBar                            | Appearance and provider toggles added here                                 | Usage, authentication, per-account data, and private runtime config stay local.                                                                                                                                                                                                      |
| Handy                               | Settings, shortcut, selected GGUF model and verified model setup           | Microphone/Accessibility consent remains local. Menu placement belongs to Thaw.                                                                                                                                                                                                      |
| MonitorControl                      | Twelve custom defaults matched this Mac                                    | Monitor capabilities, identity and actual brightness remain device-specific.                                                                                                                                                                                                         |
| Karabiner-Elements                  | Main profile and Caps tap Escape / hold Control mapping                    | macOS permissions and device availability are local.                                                                                                                                                                                                                                 |
| Raycast                             | Small settings export, four defaults, native import workflow               | Export has no snippets; extensions, commands and other live customization are not comprehensively captured. Prefer a deliberate fresh native export before promoting more settings.                                                                                                  |
| VS Code                             | User settings/keybindings and extension list                               | Accounts, workspace state, extension private data and sign-in are intentionally excluded.                                                                                                                                                                                            |
| Cursor                              | Shared editor settings/keybindings, extensions, CLI config and permissions | IDE accounts and workspace state stay local. Thaw controls menu hiding.                                                                                                                                                                                                              |
| Codex CLI / Codex app / ChatGPT     | Durable system TOML and selected shared editor settings                    | Writable user TOML can override system values. Existing `com.openai.chat` defaults target a legacy domain; this installed ChatGPT bundle uses `com.openai.codex`, and a helper has separate launcher settings. Old declarations do not prove current native GUI preference coverage. |
| Claude Code                         | Chez moi-backed CLI settings                                               | Authentication, trust and sessions stay local.                                                                                                                                                                                                                                       |
| Claude Desktop                      | Installation                                                               | Separate desktop JSON preferences, appearance and locale are untracked. Its config also contains OAuth state: do not copy the whole file. Review a safe key allowlist if desktop appearance is to be standardized.                                                                   |
| Antigravity / local Antigravity CLI | Existing Antigravity Preferences target                                    | Credentials/session state stay local; this target does not cover the separate IDE.                                                                                                                                                                                                   |
| Antigravity IDE                     | Installation                                                               | Separate `Antigravity IDE/User/settings.json` is untracked; currently contains `explorer.confirmDelete`. Extend editor settings ownership if this IDE should share managed preferences.                                                                                              |
| Docker Desktop                      | Declared settings JSON and apply-time push                                 | Live settings were denied by macOS even outside the execution sandbox. Current import code skips that denied path, so successful apply is not verification. Inspect from an appropriately authorized Terminal.                                                                       |
| iTerm2                              | Machine Dynamic Profile and quit confirmation                              | Default-profile selection, existing other profiles, global appearance and hotkeys are not comprehensively managed. Review safe defaults; do not import histories or entire profile databases.                                                                                        |
| Chrome                              | Quit-warning preference; extension inventory                               | One captured Chrome extension is compared but no browser installation policy applies it. Bookmarks, search, profiles and extension settings are not managed. Prefer native browser sync or an explicit extension policy.                                                             |
| Firefox                             | Installation; empty extension inventory                                    | Browser preferences and profiles are untracked; protected profile paths were partly unreadable. Unknown does not mean no settings.                                                                                                                                                   |
| LM Studio                           | Installation                                                               | No settings found in the two conventional locations inspected; discovery did not locate its active configuration. Coverage remains unknown.                                                                                                                                          |
| Spotify                             | Installation                                                               | Local prefs include credentials and runtime/window state. No portable subset is declared. Use app account sync where appropriate; do not copy the prefs file wholesale.                                                                                                              |
| Zoom                                | Installation                                                               | Local defaults mainly concern runtime/window/spelling state. Meeting preferences are not standardized; audio/video device IDs should remain local.                                                                                                                                   |
| Xcode (separate setup)              | Installation/setup workflow                                                | IDE preferences, accounts, signing identities, simulators and user snippets are not comprehensively managed. Signing/private account state stays outside Git.                                                                                                                        |

Built-in apps are covered only by explicit declarations in the defaults modules.
Safari extension inventory is empty and is not an installation mechanism. Weather
location order, Shortcuts, Focus configuration, notifications, privacy approvals,
and Apple Account/iCloud settings have no comprehensive transfer mechanism here.
Some are better owned by Apple's account sync or native consent UI. This review
does not establish their current cloud-sync status.

## Weather and menu controls

Enable **System Settings → Menu Bar → Menu Bar Controls → Weather** on the other
Mac. The menu weather uses the first location in Weather's list; move the intended
city to the top. [Apple's Weather instructions](https://support.apple.com/en-ie/guide/weather-mac/apdwb2768d6e/mac)
describe this supported procedure. There is no Weather option in this repo's
pinned nix-darwin module. This Mac's legacy Control Center Weather value was `2`
despite Weather being visible; copying it would not establish enabled status.

Thaw's saved Sound and Weather identifiers only arrange existing items. They
cannot enable those controls. Sound is declared using the supported
[nix-darwin option](https://nix-darwin.github.io/nix-darwin/manual/#opt-system.defaults.controlcenter.Sound).
Select the current output device on each Mac.

## Activation and acceptance

The source changes have not been applied to this Mac or the other Mac. Saved
defaults do not prove that a running app reloaded its preferences.

After the changes are committed and transferred to the other Mac:

1. Quit Stats and CodexBar so they cannot overwrite preferences on exit.
2. Run `just apply`. Complete the revised native Thaw import/apply and Raycast
   import prompts. Cancel leaves each confirmation pending.
3. Reopen Stats and CodexBar. Confirm the combined Stats order and CodexBar display
   style. Sign in to the desired providers if necessary.
4. Enable Weather as above. Check Sound and choose its output device locally.
5. Check Thaw's display associations. Allow its 15-second rehide interval to pass
   before judging whether Handy is incorrectly visible. Place the combined Stats
   item as desired; use `just export-thaw` to capture the revised native layout.
6. Run `just settings-check` for declarations/import confirmation and
   `just merge-in-settings --json` for managed file ownership/drift. Compare the
   menu bar visually on both Macs. No full computer restart is expected.

The local custom-defaults report before apply found 10 matching, 3 differing, and
0 unreadable domains. Differences included pending Stats changes, CodexBar's
unset `mergeIcons` (its upstream default is already true), and the global Zoom
shortcut's newline/carriage-return encoding. The last item needs a functional
shortcut check before treating it as broken or changing it. Nine inspected
managed file targets resolved correctly; Docker remained unreadable.

Validation passed: shell syntax, recipe listing/dry-run, Nix evaluation of custom
defaults and Sound (which renders as the supported value `18`), formatting, and
`git diff --check`. Isolated fake-command tests verified CodexBar's read-only
check, enable/disable convergence, no-op second apply, and rejection of unknown
provider IDs. Raycast tests verified that old stamps are ignored, cancellation
does not stamp success, confirmation does, and unchanged confirmed imports skip
the prompt. These tests did not apply settings to real apps.

## Further work, in priority order

1. Complete native profile/menu-control acceptance on the other Mac. Re-export
   Thaw after combined Stats is placed, removing obsolete individual-item layout.
2. Capture a deliberate Raycast native export; decide whether browser extensions
   should be enforced or owned by browser sync. Inventories alone cannot apply them.
3. Declare chosen iTerm default-profile/global appearance, Antigravity IDE user
   settings, and a safe Claude Desktop subset. Inspect desired values first rather
   than promoting private files wholesale.
4. Resolve Docker inspection access and verify its declared JSON actually loads.
5. Add app-specific acceptance checks for new managed surfaces. Extend discovery
   for shared containers and dot-directory locations; keep unreadable paths marked
   unknown. Keep credentials, hardware IDs, usage, caches and histories local.

## Implementation sources

- [CodexBar configuration and public provider CLI](https://github.com/steipete/CodexBar/blob/main/docs/configuration.md)
- [CodexBar 0.60.3 preference defaults](https://github.com/steipete/CodexBar/blob/v0.60.3/Sources/CodexBar/SettingsStore.swift)
- [Thaw 3.0.0-alpha.6 native profile application](https://github.com/thaw-app/Thaw/blob/3.0.0-alpha.6/Thaw/Settings/Models/ProfileManager+Live.swift)
- [Thaw section-default placement tests](https://github.com/thaw-app/Thaw/blob/3.0.0-alpha.6/ThawTests/MenuBar/Items/NewItemsPlacementTests.swift)
- [Stats combined-item ordering](https://github.com/exelban/stats/blob/v3.0.17/Stats/Views/CombinedView.swift)
