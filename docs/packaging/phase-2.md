# Phase 2 Packaging Plan

## Current state

The Apple Silicon development build now produces unsigned `.app` bundles and a
CLI panorama fixture, but the bundles are not yet redistributable. The current
`Hugin.app` contains only the bundle executable, icon and `Info.plist`; it still
loads runtime libraries from the build host through absolute paths and build
directory `LC_RPATH` entries.

Observed external dependencies include Homebrew libraries such as `libpano`,
`exiv2`, `wxWidgets`, `OpenEXR`, `libtiff`, `little-cms2`, `glew`, plus the
repo-local VIGRA build prefix. Those dependencies must either be bundled and
rewritten to `@rpath` or `@loader_path`, or intentionally replaced with a
controlled release dependency build.

The current bundle signature is development-only. On the local build host,
`codesign` reports an ad-hoc/linker signature, no Team Identifier, no bound
`Info.plist` and no sealed resources. This is enough for local development, but
not for Gatekeeper distribution.

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

## Phase 2 work order

1. Inspect every generated app bundle and CLI helper for external absolute
   dylib references and build-directory `LC_RPATH` entries.
2. Build or collect a closed dependency set for redistribution.
3. Copy distributable dylibs into each app bundle or into a shared package
   layout.
4. Rewrite install names and references to `@rpath`, `@loader_path` and bundled
   library paths.
5. Sign nested dylibs, helper executables, command-line tools and app bundles.
6. Enable hardened runtime with the smallest entitlement set that still launches
   and runs the panorama fixture.
7. Notarize, staple and validate the final artifact on a clean Mac account.
