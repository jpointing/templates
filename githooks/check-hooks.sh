#!/bin/sh
# Check that tracked Git hooks are active (templates repo).
#
#   sh .githooks/check-hooks.sh            # this clone and all its worktrees
#   sh .githooks/check-hooks.sh DIR...     # every clone found up to 3 levels under each DIR
#
# FAIL (exit 1): core.hooksPath unset (Git falls back to the untracked
# .git/hooks), absolute, or pointing into .git/hooks; no tracked pre-push;
# a tracked hook with CRLF line endings.
# WARN: a relative path other than .githooks; hooks not executable; live
# untracked hooks left in .git/hooks (they stop running once the path is fixed,
# so move them into .githooks first).
set -u
problems=0

check_worktree() { # <worktree path>
    wt=$1
    entry=$(git -C "$wt" config --show-scope --get core.hooksPath 2>/dev/null)
    scope=${entry%%	*}; value=${entry#*	}
    [ -n "$entry" ] || { scope='unset'; value=''; }
    report() { printf '%-4s %s: %s\n' "$1" "$wt" "$2"; [ "$1" = FAIL ] && problems=$((problems + 1)); }

    case "$value" in
        '')                       report FAIL "core.hooksPath is unset, so Git runs the untracked .git/hooks" ;;
        /*|[A-Za-z]:*|\\*)        report FAIL "core.hooksPath is absolute ($scope config: $value); every worktree runs that one copy" ;;
        *.git/hooks*|.git\\hooks*) report FAIL "core.hooksPath points into .git/hooks ($scope config), which is untracked" ;;
        .githooks|.githooks/|./.githooks) report OK "core.hooksPath = .githooks ($scope config)" ;;
        *)                        report WARN "core.hooksPath is '$value' ($scope config); the standard is .githooks" ;;
    esac

    if [ ! -f "$wt/.githooks/pre-push" ]; then
        report FAIL "no tracked .githooks/pre-push"
    fi
    for hook in "$wt"/.githooks/*; do
        [ -f "$hook" ] || continue
        case "$hook" in *.example|*.conf|*.md|*/install.sh|*/check-hooks.sh) continue ;; esac
        if grep -q "$(printf '\r')" "$hook"; then report FAIL "$(basename "$hook") has CRLF line endings"; fi
        case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) [ -x "$hook" ] || report WARN "$(basename "$hook") is not executable" ;; esac
    done

    common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    for hook in "$common"/hooks/*; do
        [ -f "$hook" ] || continue
        case "$hook" in *.sample) continue ;; esac
        name=$(basename "$hook")
        if [ -f "$wt/.githooks/$name" ]; then
            cmp -s "$hook" "$wt/.githooks/$name" || report WARN "untracked .git/hooks/$name differs from the tracked copy"
        else
            report WARN "untracked .git/hooks/$name has no tracked copy in .githooks; move it before fixing core.hooksPath"
        fi
    done
}

check_clone() { # <any path inside a clone>
    git -C "$1" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | while read -r wt; do
        [ -d "$wt" ] && check_worktree "$wt"
    done
}

if [ $# -eq 0 ]; then
    check_clone "$(git rev-parse --show-toplevel)" > /tmp/check-hooks.$$ 2>&1
else
    for dir in "$@"; do
        find "$dir" -maxdepth 3 -name .git -type d 2>/dev/null | while read -r g; do check_clone "${g%/.git}"; done
    done > /tmp/check-hooks.$$ 2>&1
fi
cat /tmp/check-hooks.$$
grep -q '^FAIL' /tmp/check-hooks.$$ && status=1 || status=0
rm -f /tmp/check-hooks.$$
exit "$status"
