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

echo "==> Looking for the latest CI run on '${BRANCH}'"

# A run can take a few seconds to appear after a push.
RUN_ID=""
for _ in $(seq 1 10); do
    RUN_ID="$(gh run list --repo "${REPO}" --branch "${BRANCH}" --limit 1 \
        --json databaseId --jq '.[0].databaseId // empty')"
    [ -n "${RUN_ID}" ] && break
    sleep 3
done

if [ -z "${RUN_ID}" ]; then
    echo "No CI run found for '${BRANCH}'. Has it been pushed?" >&2
    exit 1
fi

echo "==> Watching run ${RUN_ID}"
gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status --interval 15
