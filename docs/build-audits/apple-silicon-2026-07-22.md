# Apple Silicon Build Audit - 2026-07-22

## Scope

Initial native `arm64` build audit against the tracked upstream snapshot.

## Environment

- macOS host architecture: `arm64`
- compiler: AppleClang 21.0.0.21000101
- CMake: 4.4.0
- Ninja: 1.13.2
- Mercurial: 7.2.3
- pkg-config/pkgconf: 3.0.3
- wxWidgets: 3.3.3, toolkit `osx_cocoa`
- upstream snapshot: `439cf9058f8f761bc0e348ff22c0fa24ab26da54`

## Commands

```bash
brew install mercurial
./scripts/import-upstream-snapshot.sh
./scripts/macos/bootstrap-deps.sh
./scripts/macos/build-dev.sh
```

## Results

### Bootstrap tooling

`brew install mercurial` completed successfully.

`./scripts/macos/bootstrap-deps.sh` installed the base build tools needed for the
first configure attempt: CMake, Ninja, Mercurial and pkg-config/pkgconf.

The first bootstrap run also triggered Homebrew installed-dependent upgrades
after `pkgconf` was upgraded. That unrelated upgrade path failed while linking
`qtbase` because an existing `qt` formula owned conflicting symlinks.

Classification: dependency bootstrap isolation.

Follow-up:

- keep bootstrap focused on this repo's direct base tools;
- avoid installed-dependent upgrades during bootstrap;
- do not require Qt for the initial Hugin configure path unless an audited
  dependency requires it.

### Hugin configure

`./scripts/macos/build-dev.sh` first reached CMake configure against the ignored
Mercurial checkout and detected the current Mercurial revision:

```text
-- The C compiler identification is AppleClang 21.0.0.21000101
-- The CXX compiler identification is AppleClang 21.0.0.21000101
-- Found Hg: /opt/homebrew/bin/hg (found version "7.2.3")
-- Current HG revision is 439cf9058f8f
```

The first tracked-snapshot configure attempt showed that Mercurial archives do
not contain `rev.txt`, while upstream CMake expects that file for non-`.hg`
builds. The import workflow now writes `rev.txt` from the imported Mercurial
revision.

After adding `rev.txt`, configure stops at missing wxWidgets:

```text
Could NOT find wxWidgets (missing: wxWidgets_LIBRARIES wxWidgets_INCLUDE_DIRS)
```

Classification: dependency discovery.

Affected source/config path:

- `upstream/hugin/CMakeLists.txt`

### wxWidgets configure pass

Added `deps/macos/homebrew-formulae.txt` as the initial audited Homebrew formula
manifest and added `wxwidgets`.

`./scripts/macos/bootstrap-deps.sh` now installs formulae from that manifest and
sets `HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1` so this repo's bootstrap does
not try to upgrade unrelated installed dependents.

After installing wxWidgets 3.3.3, configure gets past wxWidgets discovery:

```text
-- Found wxWidgets: ... (found version "3.3.3")
```

Configure now stops at missing VIGRA:

```text
CMake Error at CMakeModules/FindVIGRA.cmake:92 (MESSAGE):
  Could not find VIGRA
Call Stack (most recent call first):
  CMakeLists.txt:230 (FIND_PACKAGE)
```

Classification: dependency discovery.

Affected source/config paths:

- `upstream/hugin/CMakeLists.txt`
- `upstream/hugin/CMakeModules/FindVIGRA.cmake`

## Findings

1. The upstream baseline is build-addressable from the tracked snapshot.
2. The tracked snapshot needs generated `rev.txt` build metadata because it does
   not include `.hg`.
3. The first configure blocker after metadata repair is dependency discovery for wxWidgets, not an
   AppleClang language error.
4. The bootstrap script needs to avoid unrelated Homebrew dependent upgrades;
   otherwise local environment conflicts obscure Hugin-specific failures.
5. The dev build should default to `upstream/hugin/` so audits use the tracked
   provenance baseline rather than the ignored Mercurial working copy.
6. wxWidgets 3.3.3 from Homebrew satisfies the first GUI dependency discovery
   blocker.
7. The next configure blocker is VIGRA discovery.

## Next Actions

1. Add VIGRA to the audited dependency set.
2. Re-run `./scripts/macos/build-dev.sh`.
3. Record the next failure by category, command excerpt and affected path.
