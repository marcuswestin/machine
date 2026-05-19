{ ... }:

{
  homebrew = {
    brews = [
      "btop"
      "macmon"
      "displayplacer"
    ];

    casks = [
      "google-chrome"
      "firefox"
      "nikitabobko/tap/aerospace"
      "raycast"
      # Local cask pins the marcuswestin fork release with menu bar mode for AeroSpace.
      "machine/handy/handy"
      "spotify"
      "chatgpt"
      "chatgpt-atlas"
      "claude"
      "claude-code"
      "cursor"
      "visual-studio-code"
      "iterm2"
      "docker-desktop"
      "codex-app"
      "codex"
      "steipete/tap/codexbar"
      "antigravity"
      "zoom"
      "jordanbaird-ice"
      "monitorcontrol"
      "stats"
    ];

    # Mac App Store apps that can be installed with `mas install <id>` belong in
    # `masApps`; the integer is the App Store ID (find via `mas search <name>` or
    # the `/id<NNN>` segment of an App Store URL). Xcode is intentionally handled
    # by scripts/setup-xcode.sh instead, because new Apple IDs need `mas get`
    # (get-and-install) rather than `mas install` (previously gotten apps only).
  };
}
