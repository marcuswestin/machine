{ ... }:

{
  homebrew = {
    brews = [
      "displayplacer"
    ];

    casks = [
      "google-chrome"
      "firefox"
      "nikitabobko/tap/aerospace"
      "raycast"
      "handy"
      "spotify"
      "chatgpt"
      "chatgpt-atlas"
      "claude"
      "cursor"
      "visual-studio-code"
      "iterm2"
      "docker-desktop"
      "codex-app"
      "steipete/tap/codexbar"
      "antigravity"
      "zoom"
      "monitorcontrol"
    ];

    # Mac App Store apps that can be installed with `mas install <id>` belong in
    # `masApps`; the integer is the App Store ID (find via `mas search <name>` or
    # the `/id<NNN>` segment of an App Store URL). Xcode is intentionally handled
    # by scripts/setup-xcode.sh instead, because new Apple IDs need `mas get`
    # (get-and-install) rather than `mas install` (previously gotten apps only).
  };
}
