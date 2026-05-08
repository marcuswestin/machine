# macOS Defaults To Review

The active defaults are intentionally conservative. These imported settings were
removed from the default fresh-machine activation and should be promoted only
after confirming they still apply cleanly on the target macOS version.

## Deferred Raw Domains

| Domain | Deferred Items | Rationale |
| --- | --- | --- |
| `com.apple.symbolichotkeys` | imported symbolic hotkey IDs 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 32, 33, 34, 35, 44, 45, 46, 60, 61, 64, 65, 79, 80, 81, 82, 98, 118, 119, 176, 222, 233, 235, 237, 238, 239 | brittle across macOS versions and keyboard layouts |
| `com.apple.HIToolbox` | Character Viewer, PressAndHold, Ironwood, Swedish Pro, U.S. input source records | raw input-source records are machine and OS-version sensitive |
| `com.apple.finder` | iCloud Desktop/Documents flags, sidebar disclosure state, group-by state | can affect iCloud behavior on a new machine |
| `NSGlobalDomain` | text replacements and custom `Zoom` menu shortcut | personal data and app-menu assumptions |
| trackpad raw domains | advanced multi-finger gesture mode values | keep only stable tap/click/drag defaults active for now |

## Promotion Rule

Copy a setting back into `modules/defaults.nix` only when it is:

- stable across current target macOS versions;
- understood well enough to document;
- safe to apply on a new machine without losing state or surprising iCloud behavior.
