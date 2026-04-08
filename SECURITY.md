# Security

## Secrets policy

- Do not commit Spotify tokens, refresh tokens, or any private keys.
- This repo does not commit `SpotifyFloater/Secrets.swift`.
  - Generate it locally from `SpotifyFloater/Secrets.swift.template` via `./scripts/bootstrap_secrets.sh`.
  - `SpotifyFloater/Secrets.swift` is ignored via `.gitignore`.

## If you previously committed secrets

If a secret was ever committed to a public repo, treat it as compromised:
- rotate/revoke it at the provider (Spotify/GitHub/etc.)
- consider rewriting history (e.g., `git filter-repo`) or publishing a new repo with a clean history
