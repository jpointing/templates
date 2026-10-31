#!/bin/sh
# Exercise pre-push, install.sh and check-hooks.sh against throwaway repos.
# Needs git and gitleaks. Run: sh test-hooks.sh
set -u
src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name t; git config --global user.email t@example.invalid
git config --global init.defaultBranch main; git config --global advice.detachedHead false
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
expect() { # <0|1> <name> <command...>
    want=$1; name=$2; shift 2
    if "$@" >"$tmp/out" 2>&1; then got=0; else got=1; fi
    if [ "$got" = "$want" ]; then ok "$name"; else bad "$name (got $got, want $want)"; sed 's/^/      /' "$tmp/out"; fi
}

git init -q --bare "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/seed" 2>/dev/null
cd "$tmp/seed" || exit 1
mkdir .githooks; cp "$src/pre-push" "$src/install.sh" "$src/check-hooks.sh" .githooks/
printf "HOOK_CHECK_PR_BASE=0\nHOOK_FORMAT_CHECK='! grep -rl BADFORMAT --include=*.txt .'\nHOOK_HOST_TESTS='! test -e FAILTEST'\nHOOK_HOST_TESTS_MODE=\${MODE:-block}\n" > .githooks/hooks.conf
echo one > a.txt; git add -A; git commit -qm one; git push -q origin main
cd "$tmp" || exit 1; git clone -q "$tmp/remote.git" work; cd work || exit 1
sh .githooks/install.sh >/dev/null

expect 1 "refuse push from local main" git push -q origin main:refs/heads/grok/x
git switch -q -c grok/ok
echo two >> a.txt; git commit -qam two
expect 0 "pass an up-to-date task branch" git push -q origin grok/ok
expect 1 "refuse push to main from a task branch" git push -q origin grok/ok:main
echo BADFORMAT > b.txt; git add b.txt; git commit -qm fmt
expect 1 "refuse unformatted change" git push -q origin grok/ok
git rm -q b.txt; git commit -qm unfmt
touch FAILTEST
expect 1 "refuse failing host tests (block)" git push -q origin grok/ok
expect 0 "allow failing host tests (warn)" env MODE=warn git push -q origin grok/ok
rm FAILTEST
# Built from pieces so the templates repo's own gitleaks run doesn't flag this file.
k1=AKIA; k2=Z3MSJV4WWNKWW5FG; s1=wJalrXUtnFEMI; s2=K7MDENG/bPxRfiCYzEXAMPLEKEY1
printf 'aws_secret_access_key = "%s/%s"\n%s%s\n' "$s1" "$s2" "$k1" "$k2" > creds.txt
git add creds.txt; git commit -qm leak
expect 1 "refuse a secret" git push -q origin grok/ok
grep -q "FAIL (secrets)" "$tmp/out" && ok "  ...for the secret scan" || bad "  ...for the secret scan"
git reset -q --hard HEAD~1

# Base checks: main moves on; the branch is now behind.
(cd "$tmp/seed" && git pull -q && echo three > c.txt && git add c.txt && git commit -qm three && git push -q origin main)
git switch -q -c grok/behind HEAD
expect 1 "refuse a branch behind origin/main" git push -q origin grok/behind
git fetch -q; git merge -q --no-edit origin/main
expect 0 "pass after merging origin/main" git push -q origin grok/behind

# Issues-branch base and fix branch.
git push -q --no-verify origin origin/main:refs/heads/issues/2026-01-02
git fetch -q
git switch -q -c fix/y origin/main
git config branch.fix/y.pushGateBase origin/issues/2026-01-02
echo y > y.txt; git add y.txt; git commit -qm y
expect 0 "pass a fix branch containing its issues base" git push -q origin fix/y
git config branch.fix/y.pushGateBase origin/elsewhere
echo y2 >> y.txt; git commit -qam y2
expect 1 "refuse an invalid PR base" git push -q origin fix/y
git config branch.fix/y.pushGateBase origin/issues/2026-01-02
git fetch -q; git reset -q --hard origin/main; echo z > z.txt; git add z.txt; git commit -qm z
expect 0 "allow a lease rewrite of a fix branch" git push -q --force-with-lease origin fix/y
# Someone else moves fix/y; a rewrite without fetching first must be refused.
(cd "$tmp/seed" && git fetch -q && git switch -q -c fix/y origin/fix/y && echo w > w.txt && git add w.txt \
    && git commit -qm w && git push -q --no-verify origin fix/y)
git commit -q --amend -m z2
expect 1 "refuse a rewrite of a fix branch someone else moved" git push -q -f origin fix/y
grep -q "force-with-lease" "$tmp/out" && ok "  ...suggesting fetch and --force-with-lease" || bad "  ...suggesting fetch and --force-with-lease"
expect 1 "refuse a force push to main" git push -q -f origin fix/y:main
expect 1 "refuse deleting a shared branch" git push -q origin :fix/y

# A hook from another checkout that differs is refused.
git clone -q "$tmp/remote.git" "$tmp/other"; echo '# changed' >> "$tmp/other/.githooks/pre-push"
git switch -q grok/behind
git config core.hooksPath "$tmp/other/.githooks"
expect 1 "refuse a differing hook from another checkout" git push -q origin grok/behind
expect 1 "check-hooks flags an absolute hooksPath" sh .githooks/check-hooks.sh
git config core.hooksPath .git/hooks
expect 1 "check-hooks flags .git/hooks" sh .githooks/check-hooks.sh
git worktree add -q "$tmp/wt" -b grok/wt origin/main 2>/dev/null
git -C "$tmp/wt" config extensions.worktreeConfig true
git -C "$tmp/wt" config --worktree core.hooksPath "$tmp/other/.githooks"
sh .githooks/install.sh >/dev/null; (cd "$tmp/wt" && sh .githooks/install.sh >/dev/null)
expect 0 "check-hooks passes after install, worktree included" sh .githooks/check-hooks.sh
grep -q "$tmp/wt" "$tmp/out" && ok "check-hooks lists the worktree" || bad "check-hooks lists the worktree"

exit $fail
