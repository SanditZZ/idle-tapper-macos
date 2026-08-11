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

Idle Tapper is a local menu bar app with no accounts, no telemetry and no server of its own. It makes exactly one kind of network request — a check against its update feed — and has one third-party dependency, [Sparkle](https://sparkle-project.org), which performs that check and installs updates.

The app is **not sandboxed**. Sparkle installs an update by replacing the application bundle in `/Applications`, which a sandboxed app cannot do; the sandbox was removed deliberately to allow that. The app takes no untrusted input beyond the update feed itself, which is the reason that trade was judged acceptable.

Areas that are in scope:

- **Anything in the update path** — this is the highest-value area. Accepting an update whose EdDSA signature does not verify, downgrade attacks, feed spoofing, or any route to installing an archive this project did not sign
- Privilege escalation, or writing outside the app's own directories
- Unauthorised reading or modification of the app's local database by another process
- Issues in the file export path (`NSSavePanel` handling, path traversal, writing outside a user-selected location)
- Anything that causes the app to execute untrusted code

Out of scope:

- The SQLite database being readable by the user who owns it — this is expected; it is that user's own data on their own machine
- Denial of service that requires physical access to an unlocked Mac
- Findings that depend on the user having already installed malware with equivalent privileges

## Data handling

For clarity, since it affects what a vulnerability could expose:

- Tap history is stored in a local SwiftData/SQLite database at `~/Library/Application Support/IdleTapper/`
- Preferences are stored in `UserDefaults`
- No tap data, identifier or usage information is transmitted anywhere; there is no server, no analytics and no crash reporting
- The one outbound request is a daily fetch of the public update feed, which sends nothing beyond what any HTTP request discloses. It can be turned off in Settings → Updates
- Exported JSON is written only to a location the user explicitly chooses through a save panel

## How updates are trusted

The app is not notarized by Apple, so Apple's signature is not what vouches for an update. Sparkle's is.

Every update archive is signed with an EdDSA key whose public half is compiled into the app. Sparkle refuses any archive that does not verify against it, so a compromised feed, a hijacked domain or a man-in-the-middle cannot install code — they can only fail the check.

The corresponding private key is the single point of failure. It is held in a GitHub Actions secret and never enters the repository. **If you believe that key has been exposed, treat it as critical and report it privately**, using the process above.
