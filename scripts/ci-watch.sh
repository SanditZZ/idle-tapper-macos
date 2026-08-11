#!/usr/bin/env bash
#
# ci-watch.sh — wait for the GitHub Actions runs for the current commit and
# report a single, trustworthy verdict.
#
# Two things make this less trivial than `gh run watch`:
#
#   1. **Runs are matched by commit, not branch.** A run takes a few seconds to
#      appear after a push; asking for "the latest run on this branch" inside
#      that window returns the *previous* commit's run, which may be green while
#      the new one has not even started — a success that says nothing about what
#      was just pushed.
#
#   2. **A push to a branch with an open PR fires two runs**, and the workflow's
#      concurrency group deliberately cancels one. A `cancelled` conclusion is
#      therefore normal and must not be read as a failure — but it is not a pass
#      either, so the verdict has to come from the run that actually finished.
#
# It also passes the personal account's token per invocation: `gh` defaults to
# the work account on this machine, and switching the active account would
# affect every other shell.
#
# Usage:
#   scripts/ci-watch.sh              # current commit
#   scripts/ci-watch.sh <sha>        # a specific commit
#
# Exit codes: 0 all good · 1 a run failed · 2 nothing conclusive

set -euo pipefail

REPO="SanditZZ/idle-tapper-macos"
GH_ACCOUNT="SanditZZ"
POLL_SECONDS=15
MAX_WAIT_SECONDS=1800

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SHA="$(git rev-parse "${1:-HEAD}")"
SHORT="${SHA:0:7}"

TOKEN="$(gh auth token --user "${GH_ACCOUNT}")"
export GH_TOKEN="${TOKEN}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'; GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
    BOLD=""; GREEN=""; RED=""; YELLOW=""; RESET=""
fi

runs_for_commit() {
    gh run list --repo "${REPO}" --limit 30 \
        --json databaseId,headSha,status,conclusion,event \
        --jq "[.[] | select(.headSha == \"${SHA}\")]"
}

printf '%s==>%s Waiting for CI on %s\n' "${BOLD}" "${RESET}" "${SHORT}"

ELAPSED=0
RUNS="[]"

while [ "${ELAPSED}" -lt "${MAX_WAIT_SECONDS}" ]; do
    RUNS="$(runs_for_commit)"
    TOTAL="$(printf '%s' "${RUNS}" | jq 'length')"

    if [ "${TOTAL}" -gt 0 ]; then
        PENDING="$(printf '%s' "${RUNS}" | jq '[.[] | select(.status != "completed")] | length')"
        if [ "${PENDING}" -eq 0 ]; then
            break
        fi
        printf '    %s run(s), %s still running… (%ss elapsed)\n' "${TOTAL}" "${PENDING}" "${ELAPSED}"
    else
        printf '    no run has appeared yet… (%ss elapsed)\n' "${ELAPSED}"
    fi

    sleep "${POLL_SECONDS}"
    ELAPSED=$((ELAPSED + POLL_SECONDS))
done

TOTAL="$(printf '%s' "${RUNS}" | jq 'length')"

if [ "${TOTAL}" -eq 0 ]; then
    printf '%s✗%s No CI run found for %s. Has it been pushed?\n' "${RED}" "${RESET}" "${SHORT}" >&2
    exit 2
fi

printf '\n'
printf '%s' "${RUNS}" | jq -r '.[] | "    \(.event)\t\(.status)\t\(.conclusion // "-")"'
printf '\n'

FAILED="$(printf '%s' "${RUNS}" | jq '[.[] | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure")] | length')"
SUCCEEDED="$(printf '%s' "${RUNS}" | jq '[.[] | select(.conclusion == "success")] | length')"

if [ "${FAILED}" -gt 0 ]; then
    FAILING_ID="$(printf '%s' "${RUNS}" | jq -r '[.[] | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure")] | .[0].databaseId')"
    printf '%s✗ CI FAILED for %s%s\n' "${RED}${BOLD}" "${SHORT}" "${RESET}" >&2
    printf '  gh run view %s --repo %s --log-failed\n' "${FAILING_ID}" "${REPO}" >&2
    exit 1
fi

if [ "${SUCCEEDED}" -eq 0 ]; then
    # Every run was cancelled — usually because a newer push superseded this
    # one. Nothing was actually validated, so this is not a pass.
    printf '%s! Inconclusive: every run for %s was cancelled%s\n' "${YELLOW}${BOLD}" "${SHORT}" "${RESET}" >&2
    printf '  Nothing was validated. Push again or re-run the workflow.\n' >&2
    exit 2
fi

printf '%s✓ CI passed for %s%s\n' "${GREEN}${BOLD}" "${SHORT}" "${RESET}"
