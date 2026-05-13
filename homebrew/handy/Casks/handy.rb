cask "handy" do
  version "0.8.3-aerospace.1"
  sha256 "851eb3c187c2eb3f5f63583193d8dea13f6ebada9d7fb75a8e1c11370644bbdd"

  url "https://github.com/marcuswestin/Handy/releases/download/v#{version}/Handy_0.8.3_aarch64.dmg",
      verified: "github.com/marcuswestin/Handy/"
  name "Handy"
  desc "Speech to text application"
  homepage "https://handy.computer/"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: ">= :ventura"

  app "Handy.app"

  zap trash: [
    "~/Library/Application Support/com.pais.handy",
    "~/Library/Caches/com.pais.handy",
    "~/Library/LaunchAgents/Handy.plist",
    "~/Library/WebKit/com.pais.handy",
  ]
end
