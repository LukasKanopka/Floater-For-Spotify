# Homebrew (Cask) Publishing Setup

For a macOS `.app`, Homebrew distribution is typically done via a **Cask** (not a formula).

The common setup looks like this:

1. Build + sign + notarize `SpotifyFloater.app`
2. Zip the notarized `.app` and attach it to a GitHub Release
3. Publish/update a Homebrew tap containing `Casks/spotifyfloater.rb` that points at that release asset

## 1) Prepare local secrets (for building)

This repo does not commit `SpotifyFloater/Secrets.swift`.

Create it from the template:

```sh
./scripts/bootstrap_secrets.sh
```

Edit `SpotifyFloater/Secrets.swift` and set:
- `Secrets.spotifyClientID`
- `Secrets.spotifyRedirectURI` (must match Spotify Dashboard)
- `Secrets.spotifyCallbackURLScheme` (must match `Info.plist`)

## 2) Build / sign / notarize

You can do this via Xcode (Archive) or via `xcodebuild`. The exact signing/notarization steps depend on:
- your Apple Developer Team settings
- your distribution identity (Developer ID Application)

Homebrew users will get the best experience if the app is **notarized**.

## 3) Create a release zip

From the folder containing `SpotifyFloater.app`:

```sh
ditto -c -k --sequesterRsrc --keepParent "SpotifyFloater.app" "SpotifyFloater-vX.Y.Z.zip"
shasum -a 256 "SpotifyFloater-vX.Y.Z.zip"
```

Upload the zip to a GitHub Release (tag `vX.Y.Z`).

## 4) Create a tap + cask

Create a separate repo for a tap (recommended):
- `yourname/homebrew-spotifyfloater`

In that repo, add:
- `Casks/spotifyfloater.rb`

Example cask (edit `version`, `sha256`, and `url`):

```ruby
cask "spotifyfloater" do
  version "X.Y.Z"
  sha256 "PUT_SHA256_HERE"

  url "https://github.com/YOUR_ORG/SpotifyFloater/releases/download/v#{version}/SpotifyFloater-v#{version}.zip"
  name "SpotifyFloater"
  desc "Floating Spotify controller for macOS"
  homepage "https://github.com/YOUR_ORG/SpotifyFloater"

  app "SpotifyFloater.app"

  zap trash: [
    "~/Library/Preferences/com.yourorg.SpotifyFloater.plist",
  ]
end
```

## 5) Install from the tap

Once the tap repo is pushed:

```sh
brew tap YOUR_ORG/spotifyfloater
brew install --cask spotifyfloater
```

