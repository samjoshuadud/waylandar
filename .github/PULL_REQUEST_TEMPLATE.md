## What this changes

<!-- What it does and why. If it fixes an open issue, "Fixes #123". -->

## AI assistance

<!-- Required. Pick one and delete the rest. See CONTRIBUTING.md. Disclosing
     is not a filter, it just tells the maintainer where to look harder. -->

- [ ] No AI tools used
- [ ] Partly AI-assisted (which parts):
- [ ] Mostly AI-written, reviewed by me

## How you tested it

<!-- What you actually ran, not what should work. For UI changes please give
     compositor, Quickshell version and provider, e.g.
     "Hyprland, Quickshell 0.3.1, local .ics directory". -->

- Compositor / Quickshell version:
- Provider(s) exercised:
- What you checked:

## Checklist

- [ ] One logical change
- [ ] `## [Unreleased]` entry added to `CHANGELOG.md`
- [ ] I understand this code and can explain why it works

If your change touches any of these, tick it too:

- [ ] **Added a `Theme.qml` property**: a user's existing `Theme.qml` is kept
      across upgrades and will not have it, so it falls back to the old value
- [ ] **Changed the init script**: updated all three of `PKGBUILD`,
      `flake.nix` and `contrib/nixpkgs/package.nix`
- [ ] **Added a QML singleton**: added it to `frontend/qmldir` as well
- [ ] **Added a Python dependency**: added it to all three packaging files
