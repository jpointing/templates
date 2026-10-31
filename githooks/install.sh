#!/bin/sh
# Turn on this repo's tracked hooks (templates repo). Run once per clone,
# from any worktree. Safe to re-run.
#
# Sets core.hooksPath to the relative .githooks, which Git resolves inside each
# worktree, so every worktree runs its own tracked copy. Removes any repo- or
# worktree-level override that points somewhere else (an absolute path, or
# .git/hooks, which is untracked).
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"

# Repo-level setting, shared by every worktree of this clone.
git config --local core.hooksPath .githooks
# A per-worktree override wins over the repo setting; drop it if it differs.
if git config --worktree --get core.hooksPath >/dev/null 2>&1; then
    [ "$(git config --worktree --get core.hooksPath)" = .githooks ] \
        || git config --worktree --unset-all core.hooksPath
fi
# On Windows a fresh clone can lose the executable bit; Git Bash ignores it,
# but Linux and macOS clones (CI, cloud agents) need it.
for hook in .githooks/*; do
    case "$hook" in *.example|*.conf|*.md|*/install.sh) continue ;; esac
    [ -f "$hook" ] && chmod +x "$hook"
done
echo "install: core.hooksPath = $(git config --get core.hooksPath)"
