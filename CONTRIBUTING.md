# Contributing to Waylandar

Thanks for taking the time. This is a small project, and a clear PR that does
one thing is worth more than a big one that does five.

## Running from source

```bash
git clone https://github.com/samjoshuadud/waylandar
cd waylandar
python3 backend/sync.py          # CLI / setup wizard
quickshell -p frontend/widget.qml
quickshell -p frontend/dashboard.qml
```

Running from a checkout uses `frontend/qmldir`. Installed builds never see it,
because the init script symlinks only `frontend/*.qml` into
`~/.config/waylandar`, so singletons resolve by directory there. If you add a singleton, add it to
`qmldir` too, so a source checkout keeps working.

## AI-assisted contributions

**If any part of your PR was written or drafted with an AI tool, say so in the
pull request description.** One line is enough: "written with Claude Code",
"Copilot-assisted", whatever fits.

AI-assisted PRs are welcome. This is not a filter, and disclosing costs you
nothing in review. It only tells the maintainer where to look harder: generated
code tends to be confidently wrong in different places than hand-written code
is, particularly around packaging, upgrade paths and anything that touches a
user's existing config. Adding `Co-Authored-By:` to the commit is a nice touch
but does not replace the line in the description.

Undisclosed AI code that turns out to be broken is the thing that erodes trust,
not AI use itself.

Either way, the bar is the same: you understand the code you are submitting and
can explain why it works.

## Pull requests

- One logical change per PR.
- Describe what you actually tested, and on what: compositor, Quickshell
  version, which provider. "Tested on Hyprland, Quickshell 0.3.1, local .ics"
  is far more useful than "works for me".
- Add a `## [Unreleased]` entry to [CHANGELOG.md](CHANGELOG.md) under Added /
  Changed / Fixed.
- Match the surrounding style. There is no linter to argue with.

### Things that are easy to get wrong here

Worth a second look if your change touches any of these:

- **A user's `Theme.qml` is preserved across upgrades**, so it may predate any
  property you add. New theme properties need a fallback for the case where the
  user's theme does not define them.
- **`theme_template.qml` is also preserved**, because Matugen users edit it.
- **Three packaging paths must stay in sync**: `PKGBUILD`, `flake.nix` and
  `contrib/nixpkgs/package.nix`. A change to the init script belongs in all
  three.
- New files under `frontend/` are picked up by packaging automatically; new
  Python dependencies are not, and need adding to each of the three.

## CI

Every PR runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml): Ruff on the
Python, a Semgrep scan, and `nix build .#default`. There is also a grep that
fails the build on any hardcoded `/home/` path in a `.py` or `.qml` file. Use
`os.path.expanduser("~")` or `Quickshell.env("HOME")` instead.

Run `ruff check .` before pushing and you will catch most of it locally.

## Bugs

Include your compositor, Quickshell version, how you installed Waylandar, and
the output of `quickshell -p frontend/widget.qml` if the UI is involved.
