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

This machine currently has no Developer ID certificate available:

```text
security find-identity -p codesigning -v
0 valid identities found
```

The release workflow therefore validates completely in developer mode and fails
fast in distribution mode until Apple signing and notarization credentials are
installed.

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

Use the release orchestrator for the full Phase 2 developer-mode flow. This
builds or reuses the current build, bundles dependencies, ad-hoc signs apps,
creates a DMG, mounts that DMG, verifies the contained apps and validates the
disk image checksum:

```bash
HUGIN_RELEASE_MODE=developer ./scripts/macos/package-release.sh
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

Use the DMG packager directly when the apps have already been bundled and
signed:

```bash
./scripts/macos/package-dmg.sh \
  build/macos-dev/src/hugin1/hugin/Hugin.app \
  build/macos-dev/src/hugin1/calibrate_lens/calibrate_lens_gui.app \
  build/macos-dev/src/hugin1/ptbatcher/PTBatcherGUI.app \
  build/macos-dev/src/hugin1/stitch_project/HuginStitchProject.app \
  build/macos-dev/src/hugin1/toolbox/hugin_toolbox.app
```

Use the validator directly to verify app signatures, runtime-library closure,
DMG checksum and mounted DMG contents:

```bash
HUGIN_RELEASE_MODE=developer ./scripts/macos/validate-release.sh \
  build/macos-dev/src/hugin1/hugin/Hugin.app \
  build/macos-dev/src/hugin1/calibrate_lens/calibrate_lens_gui.app \
  build/macos-dev/src/hugin1/ptbatcher/PTBatcherGUI.app \
  build/macos-dev/src/hugin1/stitch_project/HuginStitchProject.app \
  build/macos-dev/src/hugin1/toolbox/hugin_toolbox.app \
  build/artifacts/hugin-macos-community.dmg
```

Distribution mode requires a Developer ID Application identity and notarization
configuration. The signing helper enables hardened runtime with no entitlements
by default when `HUGIN_SIGN_IDENTITY` is not `-`; do not add entitlements unless
a concrete runtime failure proves one is needed.

```bash
HUGIN_RELEASE_MODE=distribution \
  HUGIN_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" \
  HUGIN_NOTARY_PROFILE=hugin-notary \
  ./scripts/macos/package-release.sh
```

`notarize-release.sh` also supports explicit notarytool credentials through
`HUGIN_NOTARY_APPLE_ID`, `HUGIN_NOTARY_PASSWORD` and `HUGIN_NOTARY_TEAM_ID`.

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

The complete local developer-mode release command was also validated with:

```bash
HUGIN_BUILD_DIR=build/macos-dev-buildsystem \
  HUGIN_SKIP_BUILD=1 \
  HUGIN_RELEASE_MODE=developer \
  HUGIN_DMG_PATH=build/artifacts/hugin-macos-community-dev.dmg \
  ./scripts/macos/package-release.sh
```

Result:

- all five app bundles were ad-hoc signed and verified;
- `hugin-macos-community-dev.dmg` was created;
- `hdiutil verify` passed;
- the DMG mounted read-only;
- all app bundles inside the mounted DMG passed `codesign --verify --deep
  --strict`.

Distribution-mode guardrail validation:

```text
Signing identity is not available in the current keychain: Developer ID Application: Missing (TEAMID)
```

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

Items 1-6 are implemented in scripts and tested in developer mode. Item 7 is
credential-gated because this machine does not currently have Developer ID or
notarization credentials.
