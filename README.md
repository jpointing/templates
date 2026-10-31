# templates

Generic templates that James's repos use. Some files are copied into a repo by a sync job; others are used as a git submodule or a GitHub Action.

Templates are generic. They must not contain hostnames, IP addresses, machine names, usernames, local paths or anything else specific to one person or setup. Those belong in the repo that uses the template.

## Git hooks

Every repo tracks its hooks in `.githooks/`, with `core.hooksPath` set to the relative `.githooks`. Never use an absolute path or `.git/hooks`: an absolute path makes every worktree run one checkout's copy, and `.git/hooks` is untracked.

| Template | Goes to | What it does |
|----------|---------|--------------|
| `githooks/pre-push` | `.githooks/pre-push` | Push gate. Refuses pushes from local `main` or a detached HEAD, pushes to `main`, and deleting or rewriting `issues/`, `fix/` or `feature/` branches. Checks that the branch contains its PR base and that an open PR targets the same base. Runs gitleaks over the commits the push adds, then the repo's formatting check and host tests. |
| `githooks/hooks.conf.example` | `.githooks/hooks.conf` | The repo's own host-test and formatting commands. Failing host tests block the push unless the repo opts in to `warn`. |
| `githooks/install.sh` | `.githooks/install.sh` | Run once per clone: sets `core.hooksPath` to `.githooks` and clears any worktree override. |
| `githooks/check-hooks.sh` | `.githooks/check-hooks.sh` | Reports whether hooks are active in a clone and all its worktrees, or in every clone under the folders given. Fails on an unset, absolute or `.git/hooks` path. |
| `cursor/environment.json`, `cursor/install.sh` | `.cursor/` | Cursor cloud agent setup: installs gitleaks, turns the hooks on, and fails the boot if they aren't active. |
| `workflows/secret-scan-full.yml` | `.github/workflows/` | Monthly gitleaks scan of the whole history. |

`githooks/test-hooks.sh` tests the hook templates and runs in this repo's CI.

For a branch whose PR targets an issues or feature branch, set its base once: `git config branch.<name>.pushGateBase origin/issues/YYYY-MM-DD`.
