#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
export_dir="${repo_root}-public-${timestamp}"

echo "Exporting sanitized repo to:"
echo "  $export_dir"

mkdir -p "$export_dir"

# Copy working tree without git history and without local secrets file.
rsync -a \
  --exclude=".git/" \
  --exclude="DerivedData/" \
  --exclude="SpotifyFloater/Secrets.swift" \
  "$repo_root/" "$export_dir/"

mkdir -p "$export_dir/SpotifyFloater"

# Ensure the export is buildable after bootstrap.
echo "Note: SpotifyFloater/Secrets.swift is intentionally not included." > "$export_dir/SECURITY_EXPORT_NOTE.txt"

echo "Done."
echo "Next:"
echo "  cd \"$export_dir\""
echo "  git init"
echo "  ./scripts/bootstrap_secrets.sh"
