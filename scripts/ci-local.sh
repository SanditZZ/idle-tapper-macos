#!/usr/bin/env bash
#
# ci-local.sh — run exactly what CI runs, locally.
#
# GitHub Actions only reports after a push, which is too late. This runs the
# same two xcodebuild invocations as .github/workflows/ci.yml with the same
# flags, so a red pipeline is caught before anything leaves the machine.
#
# Keep this file and .github/workflows/ci.yml in step: if one gains a flag, so
# must the other, or "it passed locally" stops meaning anything.
#
# Usage:
#   scripts/ci-local.sh            # build + test
#   scripts/ci-local.sh build      # build only
#   scripts/ci-local.sh test       # test only
#
# Exit code is 0 only when every stage passed.

set -euo pipefail

PROJECT="IdleTapper.xcodeproj"
SCHEME="IdleTapper"
CONFIGURATION="Debug"

# Run from the repository root regardless of where this was invoked.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

STAGE="${1:-all}"

# Colour only when attached to a terminal, so piped output stays clean.
if [ -t 1 ]; then
    BOLD=$'\033[1m'; GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; GREEN=""; RED=""; DIM=""; RESET=""
fi

info() { printf '%s==>%s %s\n' "${BOLD}" "${RESET}" "$1"; }
pass() { printf '%s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
fail() { printf '%s✗%s %s\n' "${RED}" "${RESET}" "$1" >&2; }

# `xcpretty` is what CI pipes through; fall back to raw output if absent so the
# script still works on a machine without it.
formatter() {
    if command -v xcpretty >/dev/null 2>&1; then
        xcpretty
    else
        cat
    fi
}

run_build() {
    info "Building (warnings treated as errors)"
    set -o pipefail
    xcodebuild build \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        CODE_SIGNING_ALLOWED=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        | formatter
    pass "Build clean"
}

run_test() {
    info "Testing"
    set -o pipefail
    xcodebuild test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        CODE_SIGNING_ALLOWED=NO \
        | formatter
    pass "Tests passed"
}

trap 'fail "CI checks FAILED — do not push"' ERR

case "${STAGE}" in
    build) run_build ;;
    test)  run_test ;;
    all)   run_build; run_test ;;
    *)
        fail "Unknown stage '${STAGE}' (expected: build, test, all)"
        exit 2
        ;;
esac

printf '\n%s%s✓ CI checks passed — safe to push%s\n' "${BOLD}" "${GREEN}" "${RESET}"
printf '%sAfter pushing, confirm the real run: scripts/ci-watch.sh%s\n' "${DIM}" "${RESET}"
