#!/usr/bin/env bash
# Cursor cloud agent bootstrap (templates repo). Runs after the repo is
# checked out, on every boot, so it must be idempotent and non-interactive.
#
# A cloud agent works in its own fresh clone and inherits nothing from the
# owner's PC, so the hooks are switched on here and checked before any work.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# 1. Tools the push gate needs. gitleaks is the default secret scanner; pin the
#    version so every agent scans with the same rules.
GITLEAKS_VERSION=8.30.1
if ! command -v gitleaks >/dev/null 2>&1; then
    arch=$(uname -m); case "$arch" in x86_64) arch=x64 ;; aarch64) arch=arm64 ;; esac
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${arch}.tar.gz" \
        | sudo tar -xz -C /usr/local/bin gitleaks
fi

# 2. Per-repo dependencies for host tests and formatting go here, for example:
#    python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt

# 3. Hooks on: relative core.hooksPath, then fail the boot if they aren't active.
sh .githooks/install.sh
sh .githooks/check-hooks.sh
