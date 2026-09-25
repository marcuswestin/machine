{ ... }:

{
  homebrew = {
    brews = [
      "btop"
      "macmon"
      "displayplacer"
      "gemini-cli"
      "anomalyco/tap/opencode"
      "mobile-dev-inc/tap/maestro"
      "ollama"
      "openjdk@17"
      "worktrunk"
    ];

    casks = [
      "google-chrome"
      "firefox"
      "nikitabobko/tap/aerospace"
      "karabiner-elements"
      "raycast"
      # Local cask pins upstream Handy with Metal-backed GGUF transcription.
      "machine/local/handy"
      "spotify"
      "chatgpt"
      "chatgpt-atlas"
      "claude"
      "claude-code@latest"
      "cursor"
      "lm-studio"
      "visual-studio-code"
      "iterm2"
      "docker-desktop"
      "codex-app"
      "codex"
      "steipete/tap/codexbar"
      "antigravity"
      "machine/local/antigravity-cli"
      "antigravity-ide"
      "zoom"
      "machine/local/thaw"
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
