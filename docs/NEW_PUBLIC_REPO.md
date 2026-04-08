# Publishing a new repo (clean history)

If secrets ever existed in the current repo’s history, the safest path is publishing a **new repo** with a **fresh git history**.

## 1) Create a sanitized export (no `.git/`)

From the repo root:

```sh
./scripts/export_public_repo.sh
```

This creates a new folder next to the repo (timestamped) that:
- excludes `.git/` (no history)
- excludes `SpotifyFloater/Secrets.swift`

## 2) Initialize a new git repo and push

```sh
cd /path/to/SpotifyFloater-public-YYYYMMDD-HHMMSS
git init
git add .
git commit -m "Initial import"
```

Create a new GitHub repo (empty), then:

```sh
git remote add origin git@github.com:YOUR_ORG/SpotifyFloater.git
git branch -M main
git push -u origin main
```

## 3) Confirm secrets are not present

Before making it public, verify:
- `SpotifyFloater/Secrets.swift` is not tracked
- CI secret scanning passes (see `.github/workflows/gitleaks.yml`)

## 4) Rotate anything that was exposed

If anything sensitive was ever committed anywhere public, rotate/revoke it at the provider (Spotify/GitHub/etc.).

