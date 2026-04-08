cask "spotifyfloater" do
  version "X.Y.Z"
  sha256 "PUT_SHA256_HERE"

  url "https://github.com/YOUR_ORG/SpotifyFloater/releases/download/v#{version}/SpotifyFloater-v#{version}.zip"
  name "SpotifyFloater"
  desc "Floating Spotify controller for macOS"
  homepage "https://github.com/YOUR_ORG/SpotifyFloater"

  app "SpotifyFloater.app"
end

