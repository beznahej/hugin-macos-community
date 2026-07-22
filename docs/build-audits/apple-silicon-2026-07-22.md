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
- libpano13/libpano: 2.9.23
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

### libpano13 configure pass

Added Homebrew `libpano` to `deps/macos/homebrew-formulae.txt`.
`./scripts/macos/bootstrap-deps.sh` installed libpano 2.9.23.

After installing libpano, Hugin configure finds libpano13 and completes
configuration:

```text
-- libpano13 version: 2.9.23
-- Configuring done
-- Generating done
```

Classification: dependency discovery resolved.

### Apple Silicon build-system pass

The first compile attempt after configure completion failed in
`hugin_utils/utils.cpp` for two build-system reasons:

1. `upstream/hugin/CMakeLists.txt` hard-set `CMAKE_OSX_DEPLOYMENT_TARGET` to
   `10.9` on Apple, overriding `./scripts/macos/build-dev.sh` and making
   `std::filesystem` unavailable.
2. `rev.txt` contained a trailing newline, and the non-`.hg` release path read
   that value directly into `DISPLAY_VERSION`, producing an invalid generated
   `hugin_version.h`.

The tracked snapshot now keeps the historical `10.9` default only when the
caller does not provide `CMAKE_OSX_DEPLOYMENT_TARGET`, and strips `rev.txt`
whitespace after reading it. The import script also writes `rev.txt` without a
trailing newline for future snapshots.

Verification:

```text
#define DISPLAY_VERSION "2025.1.0.439cf9058f8f built by "
```

The retry compiles `utils.cpp` with the requested deployment target:

```text
-mmacosx-version-min=13.0
```

The build now progresses into GUI targets and stops at the first wxWidgets 3.3
compatibility error:

```text
treelistctrl.cpp:4280:5: error: 'HandleOnScroll' is a private member of 'wxScrollHelperBase'
```

Classification: source compatibility with wxWidgets 3.3.

Affected source/config paths:

- `upstream/hugin/src/hugin1/hugin/treelistctrl.cpp`
- `upstream/hugin/CMakeLists.txt`
- `scripts/import-upstream-snapshot.sh`

### wxWidgets 3.3 compatibility pass

`wxScrollHelperBase::HandleOnScroll` is private in the Homebrew wxWidgets 3.3.3
headers. The legacy `treelistctrl.cpp` implementation called it directly from
`wxTreeListMainWindow::OnScroll`, which stopped the GUI build.

The compatibility fix keeps the direct call for older wxWidgets releases and
uses the normal skipped-event path for wxWidgets 3.3 and newer:

```text
#if wxCHECK_VERSION(3, 3, 0)
    event.Skip();
#else
    HandleOnScroll( event );
#endif
```

After this change, `./scripts/macos/build-dev.sh` completes successfully in
`build/macos-dev-buildsystem`.

Built GUI app bundles:

- `src/hugin1/hugin/Hugin.app`
- `src/hugin1/calibrate_lens/calibrate_lens_gui.app`
- `src/hugin1/ptbatcher/PTBatcherGUI.app`
- `src/hugin1/stitch_project/HuginStitchProject.app`
- `src/hugin1/toolbox/hugin_toolbox.app`

Built CLI tools include:

- `src/tools/pto_gen`
- `src/hugin_cpfind/cpfind/cpfind`
- `src/tools/cpclean`
- `src/tools/autooptimiser`
- `src/tools/nona`
- `src/tools/checkpto`

Classification: source compatibility with wxWidgets 3.3 resolved.

Remaining build warnings to carry forward:

- Homebrew bottles on this host are built for newer macOS versions than the
  configured `HUGIN_MACOS_DEPLOYMENT_TARGET=13.0`.
- OpenMP is not found, so multi-threaded OpenMP paths are disabled.
- FLANN and FFTW are optional and currently absent; Hugin falls back to the
  included FLANN copy and disables FFT fast cross correlation support.

### CLI panorama fixture

Added `./scripts/macos/smoke-cli-fixture.sh`. The fixture generates two
synthetic overlapping PPM images under `build/`, then runs the command-line
pipeline:

```text
pto_gen -> cpfind -> cpclean -> autooptimiser -> checkpto -> nona
```

Local verification:

```text
cpfind: Found 75 matches
checkpto: All images are connected.
nona: wrote build/smoke-cli-fixture/rendered.png
```

### CI unsigned app artifact

`.github/workflows/repository-checks.yml` now includes a `macos-dev-build` job
that:

1. installs audited Homebrew dependencies;
2. builds the source-built VIGRA dependency;
3. builds Hugin with `./scripts/macos/build-dev.sh`;
4. runs the CLI panorama smoke fixture;
5. tars the unsigned `.app` bundles so executable permissions survive artifact
   download;
6. uploads `hugin-macos-unsigned-apps.tar` as the
   `hugin-macos-unsigned-apps` artifact.

The CI packaging step now calls `./scripts/macos/package-unsigned-apps.sh` so
local builds and CI produce the same unsigned app archive layout.

The first clean-runner attempt exposed an environment gap in the Homebrew
manifest: local builds had several required Hugin libraries already installed,
but the runner did not. The manifest now lists direct configure requirements
explicitly: `libtiff`, `jpeg-turbo`, `libpng`, `openexr`, `glew` and
`little-cms2`.

### Phase 2 packaging inspection

Initial inspection of `Hugin.app` shows the development bundle is not
redistributable yet. The bundle currently contains only:

- `Contents/MacOS/Hugin`
- `Contents/Resources/Hugin.icns`
- `Contents/Info.plist`

`otool -L` reports external absolute runtime dependencies from Homebrew and the
repo-local VIGRA prefix, including `libpano`, `glew`, `OpenEXR`, `Imath`,
`libtiff`, `Exiv2`, `little-cms2`, wxWidgets libraries and
`build/deps/macos-arm64/lib/libvigraimpex.11.dylib`.

`otool -l` reports development `LC_RPATH` entries under `/opt/homebrew/lib` and
the local build tree. Those paths must be replaced by bundled-library paths
before Phase 2 distribution can pass clean-machine validation.

`codesign` currently reports an ad-hoc/linker signature, no Team Identifier, no
bound `Info.plist` and no sealed resources. That confirms the next Phase 2 slice
is dylib/rpath normalization before Developer ID signing and notarization.

Added Phase 2 entry points:

- `./scripts/macos/bundle-app-deps.sh`
- `./scripts/macos/inspect-app-deps.sh`
- `./scripts/macos/package-unsigned-apps.sh`
- `./scripts/macos/sign-app.sh`

`bundle-app-deps.sh` copies non-system runtime dependencies into
`Contents/Frameworks`, rewrites executable references to
`@executable_path/../Frameworks`, rewrites bundled-library references to
`@loader_path`, removes stale signatures before rewriting Mach-O files, and
removes absolute development rpaths from app bundles. CI now ad-hoc signs the
bundled apps before packaging them as non-Developer-ID development artifacts.

Local validation after bundling and ad-hoc signing:

- `Hugin.app`: no external absolute dependencies, no external absolute rpaths
  and no remaining `@rpath` dependency references.
- `calibrate_lens_gui.app`: no external absolute dependencies, no external
  absolute rpaths and no remaining `@rpath` dependency references.
- `PTBatcherGUI.app`: no external absolute dependencies, no external absolute
  rpaths and no remaining `@rpath` dependency references.
- `HuginStitchProject.app`: no external absolute dependencies, no external
  absolute rpaths and no remaining `@rpath` dependency references.
- `hugin_toolbox.app`: no external absolute dependencies, no external absolute
  rpaths and no remaining `@rpath` dependency references.

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
10. libpano 2.9.23 from Homebrew satisfies libpano13 dependency discovery.
11. Hugin now reaches compile after configure completion.
12. The wxWidgets 3.3 `HandleOnScroll` compatibility error is resolved.
13. A full local Apple Silicon development build now completes.
14. The CLI panorama fixture exercises project generation, control-point
    detection, cleanup, optimization, validation and rendering.
15. CI now has a macOS development build job that uploads unsigned app bundles.
16. Phase 2 now has repeatable inspection, dependency bundling, unsigned
    packaging and ad-hoc signing entry points.
17. All five built app bundles validate with no external absolute dylib
    dependencies, no external absolute rpaths and no remaining `@rpath`
    dependency references after Phase 2 processing.
18. The macOS Homebrew manifest now includes the direct image, OpenEXR, GLEW
    and LCMS dependencies needed on a clean runner.

## Next Actions

1. Configure Developer ID signing with hardened runtime once credentials are
   present.
2. Resolve Homebrew deployment-target warnings by moving release dependencies
   from bottles to a controlled dependency build.
3. Add notarization, stapling and DMG creation once Apple credentials are
   available.
