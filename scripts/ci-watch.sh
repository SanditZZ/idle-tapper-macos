#!/usr/bin/env bash
#
# ci-watch.sh — wait for the GitHub Actions run on the current branch and report.
#
# `gh run watch` needs an explicit run id when it is not attached to a terminal,
# so this resolves the most recent run for the current branch first.
#
# It also passes the personal account's token per invocation: `gh` defaults to
# the work account on this machine, and switching the active account would
# affect every other shell.
#
# Usage:
#   scripts/ci-watch.sh            # watch the current branch
#   scripts/ci-watch.sh <branch>   # watch a specific branch
#
# Exits non-zero if the run failed, so it can gate a follow-up step.

set -euo pipefail

REPO="SanditZZ/idle-tapper-macos"
GH_ACCOUNT="SanditZZ"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

BRANCH="${1:-$(git branch --show-current)}"

if [ -z "${BRANCH}" ]; then
    echo "Could not determine the current branch (detached HEAD?)" >&2
    exit 2
fi

TOKEN="$(gh auth token --user "${GH_ACCOUNT}")"
export GH_TOKEN="${TOKEN}"

# Match on the commit, not just the branch. A run takes a few seconds to appear
# after a push, and picking "the latest run on this branch" in that window
# returns the *previous* commit's run — which may be green while the new one is
# still queued, reporting a success that says nothing about what was just
# pushed.
SHA="$(git rev-parse HEAD)"
echo "==> Looking for the CI run for ${SHA:0:7} on '${BRANCH}'"

RUN_ID=""
for _ in $(seq 1 20); do
    RUN_ID="$(gh run list --repo "${REPO}" --branch "${BRANCH}" --limit 20 \
        --json databaseId,headSha \
        --jq "[.[] | select(.headSha == \"${SHA}\")] | .[0].databaseId // empty")"
    [ -n "${RUN_ID}" ] && break
    sleep 3
done

if [ -z "${RUN_ID}" ]; then
    echo "No CI run found for commit ${SHA:0:7} on '${BRANCH}'." >&2
    echo "Has it been pushed? Does the workflow trigger on this branch?" >&2
    exit 1
fi

echo "==> Watching run ${RUN_ID}"
gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status --interval 15
