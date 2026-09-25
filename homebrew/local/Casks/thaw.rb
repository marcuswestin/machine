cask "thaw" do
  version "3.0.0-alpha.6"
  sha256 "ac52e66360dbe2a57eed3f729642a3448aaab04c0a58bca004f320223aabeda3"

  url "https://github.com/thaw-app/Thaw/releases/download/#{version}/Thaw_#{version}.zip",
      verified: "github.com/thaw-app/Thaw/"
  name "Thaw"
  desc "Menu bar manager"
  homepage "https://github.com/thaw-app/Thaw/"

  auto_updates true
  # This alpha's app bundle declares LSMinimumSystemVersion 27.0 (Golden Gate).
  depends_on macos: :golden_gate

  app "Thaw.app"

  zap trash: [
    "~/Library/Caches/com.stonerl.Thaw",
    "~/Library/HTTPStorages/com.stonerl.Thaw",
    "~/Library/Preferences/com.stonerl.Thaw.plist",
    "~/Library/WebKit/com.stonerl.Thaw",
  ]
end
