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

Then **Generate Appcast** runs on the published release and updates the Sparkle feed — once the prerequisites below are in place.

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

### Turning the feed on — required before updates work at all

**GitHub Pages does not serve private repositories on the free plan**, so the feed cannot go live until the repository is public. Until then the app checks a URL that 404s, finds nothing, and says so if you press *Check Now*. Nothing breaks; updates simply do not happen.

When you make the repository public:

1. **Create the branch.**
   ```bash
   git switch --orphan gh-pages
   git commit --allow-empty -m "Initialised the update feed branch"
   git push -u origin gh-pages
   git switch -
   ```
2. **Enable Pages** — repository Settings → Pages → deploy from branch `gh-pages`, folder `/`.
3. **Add the signing key.** Export the private key from the login keychain with Sparkle's `generate_keys -x <file>`, then:
   ```bash
   GH_TOKEN="$(gh auth token --user SanditZZ)" gh secret set SPARKLE_PRIVATE_KEY \
     --repo SanditZZ/idle-tapper-macos < <exported-key-file>
   ```
   Delete the export afterwards, and keep an offline backup somewhere safe. **Losing this key means no installed copy of the app can ever be updated again** — every future release would have to be installed by hand.
4. **Generate the feed for the existing release:** run the **Generate Appcast** workflow manually with the release tag.
5. **Confirm** `https://sanditzz.github.io/idle-tapper-macos/appcast.xml` loads and lists the version.

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
| Appcast workflow fails at checkout | No `gh-pages` branch, or Pages is not enabled. See the go-live checklist above. |
| Appcast workflow fails immediately | `SPARKLE_PRIVATE_KEY` is not set. It fails deliberately rather than publishing an unsigned feed. |
| App never offers an update | `CURRENT_PROJECT_VERSION` was not incremented, or the feed is not reachable. Check Console.app, subsystem `com.kkpon3.IdleTapper`, category `Updates`. |
| Update downloads then refuses to install | Signature mismatch — the appcast was signed with a different key than the app expects. |
