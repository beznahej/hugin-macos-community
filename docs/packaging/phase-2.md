# Phase 2 Packaging Plan

## Current state

The Apple Silicon development build now produces `.app` bundles and a CLI
panorama fixture. The raw CMake app bundles are not yet redistributable before
Phase 2 processing: `Hugin.app` initially contains only the bundle executable,
icon and `Info.plist`, and it loads runtime libraries from the build host
through absolute paths and build-directory `LC_RPATH` entries.

Observed external dependencies include Homebrew libraries such as `libpano`,
`exiv2`, `wxWidgets`, `OpenEXR`, `libtiff`, `little-cms2`, `glew`, plus the
repo-local VIGRA build prefix. Those dependencies must either be bundled and
rewritten to `@rpath` or `@loader_path`, or intentionally replaced with a
controlled release dependency build.

The raw bundle signature is development-only. On the local build host,
`codesign` reports an ad-hoc/linker signature, no Team Identifier, no bound
`Info.plist` and no sealed resources. Phase 2 now replaces that with ad-hoc
signing after dependency bundling; Developer ID signing, hardened runtime,
notarization and stapling remain release-workflow tasks.

## Added tooling

Use the dependency inspector to show Mach-O files, linked dylibs, `LC_RPATH`
entries and signature metadata:

```bash
./scripts/macos/inspect-app-deps.sh \
  build/macos-dev/src/hugin1/hugin/Hugin.app
```

Use the unsigned packager to produce the CI artifact locally. It stores the app
bundles in a tar archive so executable permissions survive artifact upload and
download:

```bash
./scripts/macos/package-unsigned-apps.sh
```

Use the bundler before packaging to copy non-system dylibs into
`Contents/Frameworks`, rewrite external references to bundled paths and remove
absolute development `LC_RPATH` entries:

```bash
./scripts/macos/bundle-app-deps.sh \
  build/macos-dev/src/hugin1/hugin/Hugin.app \
  build/macos-dev/src/hugin1/calibrate_lens/calibrate_lens_gui.app \
  build/macos-dev/src/hugin1/ptbatcher/PTBatcherGUI.app \
  build/macos-dev/src/hugin1/stitch_project/HuginStitchProject.app \
  build/macos-dev/src/hugin1/toolbox/hugin_toolbox.app
```

Use the signing helper for local ad-hoc signing or Developer ID signing once
release credentials are configured:

```bash
HUGIN_SIGN_IDENTITY=- \
  ./scripts/macos/sign-app.sh build/macos-dev/src/hugin1/hugin/Hugin.app
```

```bash
HUGIN_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" \
  ./scripts/macos/sign-app.sh build/macos-dev/src/hugin1/hugin/Hugin.app
```

The bundler removes stale signatures from Mach-O files before rewriting install
names. Always run `sign-app.sh` after bundling.

## Local validation

The current Phase 2 scripts were validated against all five generated app
bundles:

- `Hugin.app`
- `calibrate_lens_gui.app`
- `PTBatcherGUI.app`
- `HuginStitchProject.app`
- `hugin_toolbox.app`

After bundling and ad-hoc signing, `inspect-app-deps.sh` reports no external
absolute dependencies, no external absolute `LC_RPATH` entries and no remaining
`@rpath` dependency references for each app bundle.

## Phase 2 work order

1. Inspect every generated app bundle and CLI helper for external absolute
   dylib references and build-directory `LC_RPATH` entries.
2. Build or collect a closed dependency set for redistribution.
3. Copy distributable dylibs into each app bundle or into a shared package
   layout.
4. Rewrite install names and references to `@rpath`, `@loader_path` and bundled
   library paths.
5. Configure Developer ID signing for nested dylibs, helper executables,
   command-line tools and app bundles.
6. Enable hardened runtime with the smallest entitlement set that still launches
   and runs the panorama fixture.
7. Notarize, staple and validate the final artifact on a clean Mac account.
