# Repository Guidelines

## Project Structure & Module Organization
- `SpotifyFloater/`: SwiftUI app sources. Entry point is `SpotifyFloater/SpotifyFloaterApp.swift`; UI in `ContentView.swift` and `PlayerView.swift`; auth/storage in `KeychainService.swift`; models in `SpotifyModels.swift`; assets in `Assets.xcassets`.
- `SpotifyFloaterTests/`: Unit tests (XCTest).
- `SpotifyFloaterUITests/`: UI tests (XCUITest).
- `SpotifyFloater.xcodeproj/`: Xcode project (targets: `SpotifyFloater`, `SpotifyFloaterTests`, `SpotifyFloaterUITests`).

## Build, Test, and Development Commands
- Open in Xcode: `open SpotifyFloater.xcodeproj` → run with `Cmd+R`.
- Build (CLI): `xcodebuild -project SpotifyFloater.xcodeproj -target SpotifyFloater -configuration Debug build`.
- Run tests (Xcode): `Cmd+U`.
- Run tests (CLI): `xcodebuild -project SpotifyFloater.xcodeproj -scheme SpotifyFloater -destination 'platform=macOS' test`.
  - Note: Ensure the scheme `SpotifyFloater` is Shared in Xcode (Product → Scheme → Manage Schemes → check “Shared”).

## Coding Style & Naming Conventions
- Swift 5+, 4-space indentation, aim for ≤120 char lines.
- Types `UpperCamelCase`; functions/vars `lowerCamelCase`; SwiftUI views end with `View` (e.g., `PlayerView.swift`).
- One top-level type per file; file name matches primary type.
- Prefer `struct` over `class` when value semantics fit. Avoid force unwraps; use `guard`/`if let` and explicit error handling.
- Keep SwiftUI idioms (`ObservableObject`, `@State`, `@Environment`) and small, composable views.

## Testing Guidelines
- Frameworks: XCTest (unit) and XCUITest (UI).
- Test files end with `Tests.swift`; test methods start with `test...`.
- Cover core logic (e.g., `KeychainService`, token refresh paths) and critical UI flows (menu bar item, window behavior).

## Commit & Pull Request Guidelines
- Commit style: short, imperative subjects (e.g., “Fix shadow artifact”, “Refactor auth flow”).
- PRs include: clear description, linked issue (if any), screenshots for UI changes, and test notes. Keep PRs focused and reasonably small.

## Security & Configuration Tips
- Do not commit real Spotify credentials. Keep `clientID`/redirect URI local; never store secrets in source.
- Tokens persist via Keychain (`KeychainService`); avoid `UserDefaults` for secrets.
- Changes to `SpotifyFloater.entitlements` should follow least-privilege and include rationale in PRs.

