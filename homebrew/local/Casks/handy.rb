cask "handy" do
  version "0.9.7"
  sha256 "f8a2ed7bbc8f6e814ae620609a184212fc9f49dac19a8921bd80ab0f4bd5783c"

  url "https://github.com/cjpais/Handy/releases/download/v#{version}/Handy_#{version}_aarch64.dmg",
      verified: "github.com/cjpais/Handy/"
  name "Handy"
  desc "Speech to text application"
  homepage "https://handy.computer/"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Handy.app"

  zap trash: [
    "~/Library/Application Support/com.pais.handy",
    "~/Library/Caches/com.pais.handy",
    "~/Library/LaunchAgents/Handy.plist",
    "~/Library/WebKit/com.pais.handy",
  ]
end
