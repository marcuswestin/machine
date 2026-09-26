cask "thaw" do
  # Upstream keeps macOS 14/15 (Sonoma/Sequoia) on its final 1.x release.
  # Minimum versions below are verified against each app's Info.plist.
  on_sequoia :or_older do
    version "1.3.0-beta.1"
    sha256 "640847ba99fb8552caf3be1c0573a14b15f08980727a0c348efa9aeeb1ed8554"

    depends_on macos: :sonoma
  end

  on_tahoe do
    version "2.0.1"
    sha256 "aafefc186a96b2e0b7868b0966df4cbe3bf6737ced3f9b25a22d6c07dc6f8fba"

    # Tahoe is macOS 26.
    depends_on macos: :tahoe
  end

  on_golden_gate :or_newer do
    version "3.0.0-alpha.6"
    sha256 "ac52e66360dbe2a57eed3f729642a3448aaab04c0a58bca004f320223aabeda3"

    # Golden Gate is macOS 27; this alpha requires its menu bar APIs.
    depends_on macos: :golden_gate
  end

  url "https://github.com/thaw-app/Thaw/releases/download/#{version}/Thaw_#{version}.zip",
      verified: "github.com/thaw-app/Thaw/"
  name "Thaw"
  desc "Menu bar manager"
  homepage "https://github.com/thaw-app/Thaw/"

  auto_updates true

  app "Thaw.app"

  zap trash: [
    "~/Library/Caches/com.stonerl.Thaw",
    "~/Library/HTTPStorages/com.stonerl.Thaw",
    "~/Library/Preferences/com.stonerl.Thaw.plist",
    "~/Library/WebKit/com.stonerl.Thaw",
  ]
end
