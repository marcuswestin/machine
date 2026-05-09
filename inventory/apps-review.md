# Apps And Packages To Review

Active config intentionally contains only the safe-core fresh-machine set.
Deferred items below were observed or previously declared and can be promoted
back into `modules/apps.nix` after review.

## Deferred Homebrew Formulae

| Item | Source | Status |
| --- | --- | --- |
| `oven-sh/bun/bun` | previously active | replaced by Nix `bun` |
| `homebrew/core/cocoapods` | previously active | replaced by Nix `cocoapods` |
| `homebrew/core/cmake` | previously active | move to Nix or reactivate if needed |
| `homebrew/core/ffmpeg` | previously active | move to Nix or reactivate if needed |
| `homebrew/core/mkcert` | previously active | move to Nix or reactivate if needed |
| `homebrew/core/nx` | previously active | reactivate if global Nx remains useful |
| `homebrew/core/wget` | previously active | move to Nix or reactivate if needed |
| `clojure/tools/clojure` | previously commented | optional language runtime |
| `openjdk@17` | previously commented | optional language runtime |
| `python@3.13` | previously commented | optional language runtime |
| `golang-migrate` | previously commented | optional database tool |
| `postgresql@18` | previously commented service | review before enabling service |
| `gh` | previously commented | promoted to Nix package for GitHub auth |
| `ollama` | previously commented | optional local model runtime |
| `whisper-cpp` | previously commented | optional local speech tool |
| `gemini-cli` | previously commented | optional AI CLI |
| `duti` | previously commented | optional default-app tool |
| `tesseract` | previously commented | optional OCR tool |
| `sox` | previously commented | optional audio tool |
| `watchman` | previously commented | optional dev watcher |
| `felixkratz/formulae/borders` | previously commented | optional window-border service |
| `mobile-dev-inc/tap/maestro` | previously commented | optional mobile testing tool |
| `yarn` | previously commented | optional Node package manager |

## Deferred Homebrew Casks

| Item | Source | Status |
| --- | --- | --- |
| `steipete/tap/codexbar` | previously active | optional agent stats menu bar app |
| `codex` | previously active | optional agent app |
| `claude-code` | previously active | optional agent app |
| `darrylmorley/whatcable/whatcable` | previously commented | optional cable utility |
| `hiddenbar` | previously commented | optional menu bar utility |
| `stats` | previously commented | optional menu bar utility |
| `notion` | previously commented | optional productivity app |
| `wave` | previously commented | optional editor |
| `zed` | previously commented | optional editor |
| `warp` | previously commented | optional terminal |
| `ngrok` | previously commented | optional tunnel tool |
| `monitorcontrol` | previously commented | optional monitor utility |
| `jurplel/tap/instant-space-switcher` | previously commented | optional Spaces utility |

## User Safari Web Apps

- Gmail
- Google AI Studio
- Google Gemini
- NotebookLM
- oMLX Chat

## App Store Or Manual Review

- GarageBand
- iMovie
- Keynote
- Numbers
- Pages
- TestFlight
- Xcode

## Installed Apps To Map Or Keep Manual

- Antigravity
- ChatGPT Atlas
- ChatHub
- Chatbox
- Code AI
- Developer
- Gemini
- Goose
- Hand Mirror
- Highlight
- Jan
- KodexLink
- LocalWhisper
- Minecraft
- OpenCode
- OpenWhispr
- Pixelfed
- Playlisty for Apple Music
- Prime Video
- Swift Playground
- Vy
- Whisper Transcription
- Wispr Flow
- WordFlower
- oMLX
- zoom.us
