# Releasing Idle Tapper

How a version gets from this repository onto someone's Mac.

Releases are **triggered by the version changing**, not by pushing a tag and not by every commit. Merge something to `main` whose `MARKETING_VERSION` has no matching tag, and CI builds, packages and publishes it. Merge anything else and nothing happens.

---

## Cutting a release

### 1. Bump both version numbers

In Xcode, or directly in `IdleTapper.xcodeproj/project.pbxproj`:

| Setting | What it is | Rule |
|---|---|---|
| `MARKETING_VERSION` | The version users see, e.g. `0.2.0` | Semver. This is what the tag is built from. |
| `CURRENT_PROJECT_VERSION` | The build number | **Always increment.** This is what Sparkle compares to decide an update exists. |

Both live in the app target's Debug *and* Release configurations — change all four values, or a debug build reports a different version than it ships as.

> **`CURRENT_PROJECT_VERSION` is the one that matters for updates.** Sparkle orders versions by build number. Ship a new `MARKETING_VERSION` with a stale build number and installed copies will not see it as newer.

### 2. Write the changelog entry

Add a section at the top of `CHANGELOG.md`, above the previous version:

```markdown
## [0.2.0] — 2026-09-01

### Added

- Something a user would notice
```

The release workflow lifts this section verbatim into the release notes, stopping at the next `## [` heading or at the link-reference block. If there is no section for the version, the notes fall back to pointing at the commit history — which is a worse release page, so write the section.

### 3. Verify locally before pushing

```bash
./scripts/ci-local.sh                          # must exit 0 — never push red
scripts/package-release.sh                     # mirrors the release workflow's build and packaging
```

The second script is not part of CI. It runs the same version parsing, ad-hoc signing, `ditto` archiving, `hdiutil` DMG creation and changelog extraction the workflow does, and drops installable artifacts in `build/dist/`. Install the DMG and confirm the app actually runs before you publish it to anyone.

### 4. Merge to main

Open a PR and merge it server-side. The **Release** workflow then:

1. Reads `MARKETING_VERSION` from the resolved build settings and checks for a `v<version>` tag. If the tag exists it stops — this is what keeps ordinary commits from cutting releases.
2. Builds Release with warnings as errors.
3. Signs — Developer ID if the certificate secrets exist, ad-hoc if not.
4. Packages `IdleTapper-<version>.zip` (via `ditto`, never `zip`), `IdleTapper-<version>.dmg`, and `checksums-<version>.txt`.
5. Builds the release notes, prepending install instructions and the Gatekeeper bypass when the build is unnotarized.
6. Creates the GitHub release, which creates the tag.

7. Calls **Generate Appcast** as a second job, which signs the zip and commits the updated feed to `gh-pages`.

The appcast is invoked as a job rather than left to the `release: published` event, because that event never arrives: a release created by a workflow is created by `GITHUB_TOKEN`, and GitHub will not start new workflow runs from events that token raises. v0.1.0 shipped with no appcast for exactly this reason, and it failed silently — the release looked perfect while nothing installed was ever told about it.

To re-run a release for a version that already has a tag, dispatch the workflow manually with `force: true`. It deletes and recreates the release and its tag.

---

## Automatic updates

Idle Tapper updates itself with [Sparkle](https://sparkle-project.org). Because the app is not notarized by Apple, Sparkle's own **EdDSA signature** is what makes an update trustworthy: the app carries the public key in `Info.plist` and refuses any archive whose signature does not verify against it.

That means **the signing key is the security boundary**. Anyone holding the private key can ship code to every installed copy of the app.

| | |
|---|---|
| Public key | In `IdleTapper/Info.plist` as `SUPublicEDKey`. Safe to commit; it is already committed. |
| Private key | In the login keychain (item `https://sparkle-project.org`), and in the `SPARKLE_PRIVATE_KEY` repository secret. **Never in the repository.** |
| Feed | `https://sanditzz.github.io/idle-tapper-macos/appcast.xml` |
| Cadence | Daily, on by default, switchable in Settings → Updates |

### The feed, and how it is hosted

Already set up, as of v0.1.0 — this is recorded so it can be rebuilt if it is ever lost:

- **`gh-pages` branch** holds `appcast.xml` and `releases/`. It contains no source, and its README says as much. Never edit either by hand: the appcast carries a signature over each archive, and a hand-edited file fails verification in every installed copy.
- **GitHub Pages** serves that branch from the repository root. Pages is only free on public repositories, which is part of why this one is public.
- **`SPARKLE_PRIVATE_KEY`** is set as a repository secret.

Keep an offline backup of the private key — a password manager is the right place. **Losing it means no installed copy of the app can ever be updated again**; every future version would have to be installed by hand, by every user.

### If the key is ever lost or compromised

There is no revocation. Generate a new key pair, put the new public key in `Info.plist`, ship a release **installed manually by every user**, and regenerate the appcast with the new key. Treat this as the disaster it is and keep a backup.

---

## Code signing and notarization

Today the app ships **ad-hoc signed and unnotarized**, because notarization requires the paid Apple Developer Program and this project has only a free Apple Development certificate. Users clear the quarantine flag once on first install; Sparkle handles every update after that, so the prompt does not recur.

The release workflow already contains the signed path. It switches on by itself the moment these secrets exist — no edits required:

| Secret | What it holds |
|---|---|
| `DEVELOPER_CERTIFICATE_BASE64` | `base64 -i cert.p12` of an exported **Developer ID Application** certificate |
| `CERTIFICATE_PASSWORD` | The password set when exporting the `.p12` |
| `APPLE_ID` | The Apple ID owning the Developer Program membership |
| `APPLE_ID_PASSWORD` | An **app-specific password**, not the account password |
| `APPLE_TEAM_ID` | The 10-character team identifier |

```bash
GH_TOKEN="$(gh auth token --user SanditZZ)" gh secret set DEVELOPER_CERTIFICATE_BASE64 \
  --repo SanditZZ/idle-tapper-macos < certificate.b64
```

With those present the workflow imports the certificate into a temporary keychain, signs with hardened runtime and a timestamp, submits to `notarytool`, and staples the ticket. The README's Gatekeeper section should be softened once that ships.

---

## Conventions worth not relitigating

- **`ditto -c -k --keepParent`, never `zip`.** Plain `zip` mangles symlinks and bundle structure and invalidates the signature. Sparkle rejects the result.
- **Tags are `vX.Y.Z`** and are created by `gh release create`, not pushed separately, so the tag and the release can never disagree.
- **The changelog is the release notes.** Write it for a user, not a reviewer.
- **Never weaken `ci-local.sh` or `ci.yml` to make a release pass.** They are deliberately identical; if one gains a flag so must the other.

---

## When something goes wrong

| Symptom | Cause |
|---|---|
| Release workflow ran and published nothing | `MARKETING_VERSION` already has a tag. Intended. Bump the version. |
| "Could not read MARKETING_VERSION" | `xcodebuild -showBuildSettings` failed — usually a project file that does not open. Run it locally to see the real error. |
| Notes say "See the commit history" | No `## [<version>]` section in `CHANGELOG.md` for this version. |
| Appcast workflow fails at checkout | No `gh-pages` branch, or Pages is not enabled. See the feed section above. |
| Appcast workflow fails immediately | `SPARKLE_PRIVATE_KEY` is not set. It fails deliberately rather than publishing an unsigned feed. |
| A release published but the feed did not update | The appcast job was skipped or failed. Re-run it with **Generate Appcast** → Run workflow → the release tag. |
| App never offers an update | `CURRENT_PROJECT_VERSION` was not incremented, or the feed is not reachable. Check Console.app, subsystem `com.kkpon3.IdleTapper`, category `Updates`. |
| Update downloads then refuses to install | Signature mismatch — the appcast was signed with a different key than the app expects. |
