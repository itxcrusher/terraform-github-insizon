#!/usr/bin/env bash
# Commit and push all changes to the current Git branch.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"

cd "$REPO_ROOT"

# Basic safety: do not commit secrets. The 'private/' directory should already be gitignored.
# You can extend this with additional checks as needed.

if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git add -A
git commit -m "Infrastructure updates"
git push
