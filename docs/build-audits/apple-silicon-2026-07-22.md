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
- VIGRA: 1.12.4, source-built from `Version-1-12-4`
- Exiv2: 0.28.8
- upstream snapshot: `439cf9058f8f761bc0e348ff22c0fa24ab26da54`

## Commands

```bash
brew install mercurial
./scripts/import-upstream-snapshot.sh
./scripts/macos/bootstrap-deps.sh
./scripts/macos/build-vigra.sh
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

### VIGRA source dependency pass

Homebrew does not currently provide a `vigra` formula, so VIGRA is now treated
as a source-built dependency and installed under the repo-local dependency
prefix:

```text
build/deps/macos-arm64/
```

The source dependency is locked in `deps/macos/source-deps.txt`:

```text
vigra https://github.com/ukoethe/vigra.git Version-1-12-4 de98f930b66d461360a2d5dc8f9adfa84bb01058 MIT
```

`./scripts/macos/build-vigra.sh` builds VIGRA with:

- `BUILD_DOCS=OFF`
- `BUILD_TESTS=OFF`
- `WITH_VIGRANUMPY=OFF`
- `WITH_HDF5=OFF`
- `WITH_OPENEXR=ON`

The VIGRA 1.12.4 CMake package target still depends on `doc_cpp` even when
docs are disabled, so the dependency build applies
`deps/macos/patches/vigra-1.12.4-package-src-doc-target.patch`. That patch only
guards the `PACKAGE_SRC_TAR -> doc_cpp` dependency when the docs target exists.

VIGRA builds and installs successfully:

```text
-- Configuring VIGRA version 1.12.4
--   Using OpenEXR  libraries: OpenEXR::OpenEXR;OpenEXR::Iex;OpenEXR::IlmThread;Imath::Imath
--   FFTW libraries not found (FFTW support disabled)
--   HDF5 disabled by user (WITH_HDF5=0)
--   Vigranumpy disabled by user (WITH_VIGRANUMPY=0)
VIGRA installed into .../build/deps/macos-arm64
```

The dependency linker currently warns that some Homebrew bottles were built for
a newer macOS version than `HUGIN_MACOS_DEPLOYMENT_TARGET=13.0`. This is not the
current configure blocker, but it must be resolved before Phase 2 distribution
work can claim a supported deployment target.

After the local VIGRA prefix is present, Hugin configure finds VIGRA:

```text
-- Found VIGRA: .../build/deps/macos-arm64/lib/libvigraimpex.dylib
-- VIGRA version: 1.12.4
```

Configure now stops at missing Exiv2:

```text
Could NOT find Exiv2 header files
Cannot find Exiv2 library!
```

Classification: dependency discovery.

Affected source/config paths:

- `upstream/hugin/CMakeLists.txt`
- `upstream/hugin/CMakeModules/FindEXIV2.cmake`

### Exiv2 configure pass

Added `exiv2` to `deps/macos/homebrew-formulae.txt`.
`./scripts/macos/bootstrap-deps.sh` installed Exiv2 0.28.8, plus the direct
formula dependencies `inih` 62 and `libssh` 0.12.1.

After installing Exiv2, Hugin configure gets past metadata dependency
discovery:

```text
-- Found Exiv2 release >= 0.12
-- Found Exiv2: /opt/homebrew/lib/libexiv2.dylib
```

Configure now stops at missing libpano13:

```text
libpano13 not found
```

Classification: dependency discovery.

Affected source/config paths:

- `upstream/hugin/CMakeLists.txt`
- `upstream/hugin/CMakeModules/FindPANO13.cmake`

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
7. VIGRA is not available from Homebrew, but VIGRA 1.12.4 can be built from the
   official source tag into the repo-local dependency prefix.
8. Hugin now discovers VIGRA from that local prefix.
9. Exiv2 0.28.8 from Homebrew satisfies metadata dependency discovery.
10. The next configure blocker is libpano13 discovery.

## Next Actions

1. Add libpano13 to the audited dependency set.
2. Re-run `./scripts/macos/build-dev.sh`.
3. Record the next failure by category, command excerpt and affected path.
