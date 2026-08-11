# Security Policy

## Supported versions

Idle Tapper is developed on the `main` branch. Security fixes are applied to the latest release only.

| Version | Supported |
|---|---|
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

**Please do not open a public GitHub issue for a security problem.**

Report it privately using [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) on this repository, or by emailing the maintainer.

Please include:

- A description of the issue and its impact
- Steps to reproduce
- The affected version and your macOS version
- Any suggested fix, if you have one

You can expect an acknowledgement within a few days and an assessment shortly after. If the report is valid, we will agree a disclosure timeline with you and credit you in the release notes unless you prefer otherwise.

## Scope

Idle Tapper is a local, sandboxed menu bar app. It has **no network code**, no accounts, no telemetry, and no third-party dependencies, which keeps the attack surface small.

Areas that are in scope:

- Sandbox escape or privilege escalation
- Unauthorised reading or modification of the app's local database by another process
- Issues in the file export path (`NSSavePanel` handling, path traversal, writing outside a user-selected location)
- Anything that causes the app to execute untrusted code

Out of scope:

- The SQLite database being readable by the user who owns it — this is expected; it is that user's own data on their own machine
- Denial of service that requires physical access to an unlocked Mac
- Findings that depend on the user having already installed malware with equivalent privileges

## Data handling

For clarity, since it affects what a vulnerability could expose:

- Tap history is stored in a local SwiftData/SQLite database inside the app's sandbox container
- Preferences are stored in `UserDefaults`
- Nothing is transmitted anywhere; there is no server, no analytics and no crash reporting
- Exported JSON is written only to a location the user explicitly chooses through a save panel
