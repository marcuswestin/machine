cask "thaw" do
  version "1.2.0"
  sha256 "d67f4d31ef9fa057849a98540b810cfa42e0bc66019d3605abd08e45c69aa06f"

  url "https://github.com/stonerl/Thaw/releases/download/#{version}/Thaw_#{version}.zip",
      verified: "github.com/stonerl/Thaw/"
  name "Thaw"
  desc "Menu bar manager"
  homepage "https://github.com/stonerl/Thaw/"

  auto_updates true
  # Upstream homebrew-cask uses `depends_on macos: :sonoma`, which rejects macOS 15+.
  # nix-homebrew installs from tapped cask files (HOMEBREW_NO_INSTALL_FROM_API), so
  # that restriction blocks apply on newer macOS even though Thaw runs fine there.
  depends_on macos: ">= :sonoma"

  app "Thaw.app"

  zap trash: [
    "~/Library/Caches/com.stonerl.Thaw",
    "~/Library/HTTPStorages/com.stonerl.Thaw",
    "~/Library/Preferences/com.stonerl.Thaw.plist",
    "~/Library/WebKit/com.stonerl.Thaw",
  ]
end
