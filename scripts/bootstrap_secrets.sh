#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

template="$repo_root/SpotifyFloater/Secrets.swift.template"
dest="$repo_root/SpotifyFloater/Secrets.swift"

if [[ ! -f "$template" ]]; then
  echo "Missing template: $template" >&2
  exit 1
fi

if [[ -f "$dest" ]]; then
  echo "Secrets already exists: $dest"
  exit 0
fi

cp "$template" "$dest"
echo "Created: $dest"
echo "Edit Secrets.spotifyClientID before building."
