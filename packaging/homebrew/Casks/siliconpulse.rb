cask "siliconpulse" do
  version "1.0.1"
  sha256 "c4cf1062c555c544a57f6118062e723e34d6447e51bfc850861398d8bef11f59"

  url "https://github.com/alan13367/SiliconPulse/releases/download/v#{version}/SiliconPulse-#{version}.dmg"
  name "SiliconPulse"
  desc "Minimal menu bar system monitor"
  homepage "https://github.com/alan13367/SiliconPulse"

  depends_on macos: :sonoma

  app "SiliconPulse.app"

  zap trash: [
    "~/Library/Application Support/SiliconPulse",
    "~/Library/Preferences/com.alan13367.SiliconPulse.plist",
    "~/Library/Saved Application State/com.alan13367.SiliconPulse.savedState",
  ]
end
