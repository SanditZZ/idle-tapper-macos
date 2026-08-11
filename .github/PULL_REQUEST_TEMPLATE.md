## What changed

<!-- Describe the change and, more importantly, why it was needed. -->

## Why this approach

<!-- Note any alternatives you considered and rejected, and any constraints that shaped the design. -->

## Scope

<!-- Anything you deliberately did NOT do, and why. -->

## Checklist

- [ ] `./scripts/ci-local.sh` passes locally **before** pushing
- [ ] The GitHub Actions run on this branch is green
- [ ] New logic has unit tests, and edge cases are covered
- [ ] Pure logic lives in `Shared/Logic/` and takes no dependency on SwiftData or I/O
- [ ] No `ModelContext` / `@Model` usage outside `Shared/Persistence/`
- [ ] Fonts, spacing, radii and colors come from `DesignTokens` / `AppColors`, not literals
- [ ] Errors are caught, logged via `AppLog`, and degrade gracefully

## UI changes

<!-- Delete this section if the change is not user-facing. -->

| Change | Where to test | What to check |
|---|---|---|
|  |  |  |

- [ ] Checked in **light** appearance
- [ ] Checked in **dark** appearance
- [ ] Checked empty / error states

## Screenshots

<!-- Before and after, for anything visual. -->
