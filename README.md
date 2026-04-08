SpotifyFloater – OAuth PKCE (No Client Secret) Distribution Guide

Overview
SpotifyFloater now uses Spotify OAuth Authorization Code with PKCE. This lets every user sign in with their own regular Spotify account (no developer account needed). The app ships only a public client_id and never embeds a client_secret. All API calls are made on behalf of the signed-in user, so your “one API key” is no longer used for everyone’s traffic.

Key files to review:
- [SpotifyFloater/SpotifyFloaterApp.swift](SpotifyFloater/SpotifyFloaterApp.swift)
- [SpotifyFloater/ContentView.swift](SpotifyFloater/ContentView.swift)
- [SpotifyFloater/PlayerView.swift](SpotifyFloater/PlayerView.swift)
- [SpotifyFloater/SpotifyModels.swift](SpotifyFloater/SpotifyModels.swift)
- [SpotifyFloater/Info.plist](SpotifyFloater/Info.plist)
- [SpotifyFloater/KeychainService.swift](SpotifyFloater/KeychainService.swift)

What changed (high level)
- Replaced Authorization Code + client_secret with Authorization Code + PKCE in [SpotifyFloater/SpotifyFloaterApp.swift](SpotifyFloater/SpotifyFloaterApp.swift).
- Removed all uses of Basic Authorization header for token exchange/refresh. Token requests now include client_id and, for exchange, code_verifier.
- Added token storage in macOS Keychain via [SpotifyFloater/KeychainService.swift](SpotifyFloater/KeychainService.swift).
- Added token expiry tracking and proactive refresh, plus 401 and 429 backoff handling.
- Kept the custom URL scheme spotifycontroller://callback in [SpotifyFloater/Info.plist](SpotifyFloater/Info.plist) to receive the OAuth redirect.

Important notes
- Users need Spotify Premium to control playback via /me/player endpoints.
- Only you (the app developer) need one Spotify Developer app (client_id). Regular end users do not need developer accounts; they just log in.
- All network calls are over HTTPS, and no secrets are shipped.

Setup (one-time, developer)
1) Create a Spotify Developer App
   - Go to https://developer.spotify.com/dashboard
   - Create an app. Copy the Client ID.
   - In your app settings, add a redirect URI: spotifycontroller://callback
     - This must match exactly what the app uses.

2) Configure this project
   - This repo intentionally does not commit `SpotifyFloater/Secrets.swift`.
   - Create it from the template and then set your Client ID:
     - `./scripts/bootstrap_secrets.sh`
     - Edit `SpotifyFloater/Secrets.swift` and set `Secrets.spotifyClientID`.
   - Confirm [SpotifyFloater/Info.plist](SpotifyFloater/Info.plist) includes the URL scheme `spotifycontroller`.

3) Build and run
   - Run the app from Xcode.
   - Click “Login with Spotify” and complete the OAuth flow.
   - After the first successful login, a refresh token is stored securely in Keychain. On subsequent launches the app refreshes automatically without prompting the user.

Security and token handling
- PKCE
  - On sign-in, the app generates a random code_verifier and computes code_challenge = S256(verifier). No client_secret is used at any point.
  - The returned authorization code can only be exchanged by whoever knows the original verifier, keeping the flow secure for public clients.

- State parameter
  - The app generates and validates a cryptographically random state value to prevent CSRF.

- Keychain storage
  - Refresh tokens are stored using [SpotifyFloater/KeychainService.swift](SpotifyFloater/KeychainService.swift).
  - If a legacy UserDefaults refresh token is discovered, it is migrated to Keychain automatically.

- Expiry and refresh
  - The app tracks expires_in and computes an expiresAt timestamp.
  - It refreshes a few minutes before expiry and also on-demand if a 401 is encountered.

- Rate limiting
  - If a 429 is returned, the app retries once after the Retry-After period.

End-user experience
- The first run presents “Login with Spotify”.
- After login, the app can control playback and manage favorites for that user.
- On subsequent launches, the app uses the stored refresh token to retrieve a new access token.
- Users can log out (clears tokens) and log in to a different account.

Distribution considerations
- You can safely distribute this app without a client_secret.
- Ensure your client_id’s Spotify Developer app has spotifycontroller://callback whitelisted.
- If you rotate the client_id in the future, release a new app build with the updated value.

Troubleshooting
- “Login does not return to the app”:
  - Confirm that [SpotifyFloater/Info.plist](SpotifyFloater/Info.plist) contains the CFBundleURLTypes / CFBundleURLSchemes entry "spotifycontroller".
  - Confirm the exact redirect URI spotifycontroller://callback is configured in the Spotify Dashboard.

- “401 Unauthorized after refresh”:
  - The user’s refresh token may have been revoked. Logging out and in again will fix it.

- “403 device not active”:
  - Spotify requires an active playback device. Start playback on a Spotify device (phone/desktop app) and try again.

- “429 Too Many Requests”:
  - The app backs off once based on Retry-After. Avoid polling at very high frequency.

Manual QA checklist (developer)
- First run: Sign in, verify player controls (play/pause/next/previous) and favorites.
- Kill and relaunch: Verify auto-refresh from Keychain without login prompts.
- Revoke access in spotify.com account settings: App should detect refresh failure and require re-auth.
- Verify rate-limit behavior by simulating heavy requests: confirm 429 backoff logic.

Design choices audited
- Public client only: ships client_id, no client_secret.
- PKCE + ASWebAuthenticationSession: best practice for macOS public apps.
- Keychain for tokens, never UserDefaults.
- Custom URL scheme for deep-link callback.

Where to change values
- Client ID / Redirect URI:
  - `SpotifyFloater/Secrets.swift` (generated locally from `SpotifyFloater/Secrets.template.swift`)
  - Redirect URI must stay aligned with [SpotifyFloater/Info.plist](SpotifyFloater/Info.plist) and the Spotify Dashboard

Homebrew distribution
- See `docs/HOMEBREW_CASK.md` for a Homebrew Cask-based publishing flow (zip notarized app → GitHub Release → tap cask points at that asset).

Licensing and acknowledgments
- Spotify API usage subject to Spotify Developer Terms.
- This project uses Apple CryptoKit for SHA256 and base64url transformation.
