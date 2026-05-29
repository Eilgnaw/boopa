# Homebrew cask for Boopa.
#
# `version` and `sha256` below are kept up to date automatically by the release
# workflow (.github/workflows/release.yml) on every tagged release.
#
# Install (after tapping — see README/CLAUDE.md for tap setup):
#   brew install --cask Eilgnaw/tap/boopa
# Or directly from this repo:
#   brew install --cask https://raw.githubusercontent.com/Eilgnaw/boopa/main/Casks/boopa.rb
cask "boopa" do
  version "1.0.2"
  sha256 "2c1d5129e112970d378460af4f4c43ed648f7f52aeab6d522fd96a799b88720e"

  url "https://github.com/Eilgnaw/boopa/releases/download/v#{version}/Boopa-#{version}.dmg"
  name "Boopa"
  desc "Screen-edge glow notifications that signal when an AI agent needs attention"
  homepage "https://github.com/Eilgnaw/boopa"

  depends_on macos: ">= :sequoia" # macOS 15+

  app "Boopa.app"
  # Put the bundled CLI on the Homebrew PATH as `boopa`.
  binary "#{appdir}/Boopa.app/Contents/MacOS/Boopa", target: "boopa"

  zap trash: [
    "~/.config/boopa",
    "~/Library/Caches/com.eilgnaw.boopa",
    "~/Library/Preferences/com.eilgnaw.boopa.plist",
  ]
end
