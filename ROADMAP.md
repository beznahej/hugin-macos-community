# Roadmap

## Phase 0 — Repository and provenance

- [x] Establish public-project scope and naming.
- [x] Document upstream source and licensing.
- [x] Define the Mac architecture and product direction.
- [x] Add bootstrap scripts and issue templates.
- [x] Import the current upstream source baseline with provenance.
- [x] Decide whether to preserve full Mercurial history or use periodic vendor snapshots.

## Phase 1 — Reproducible Apple Silicon development build

- [ ] Build Hugin natively on `arm64` using current Xcode command-line tools.
- [ ] Remove hardcoded `/usr/local`, `-march=core2` and x86-only OpenMP settings.
- [ ] Establish a version-locked dependency manifest.
- [ ] Integrate known wxWidgets 3.3 compatibility fixes with attribution.
- [ ] Add an end-to-end command-line panorama fixture.
- [ ] Produce an unsigned development `.app` artifact in CI.

**Exit criterion:** a clean GitHub-hosted macOS runner can build and execute the
core panorama pipeline without manual edits.

## Phase 2 — Proper Mac application distribution

- [ ] Normalize `@rpath`, `@loader_path` and bundled dylib handling.
- [ ] Sign nested executables, dylibs, helper tools and application bundles.
- [ ] Enable hardened runtime with minimal entitlements.
- [ ] Add notarization and ticket stapling.
- [ ] Produce a signed DMG.
- [ ] Validate with `codesign`, `spctl`, `stapler` and clean-machine tests.

**Exit criterion:** a user can download, install and launch the application on a
supported Mac without bypassing Gatekeeper.

## Phase 3 — Native simplified workflow

- [ ] Create a SwiftUI/AppKit shell.
- [ ] Import from Finder and Photos.
- [ ] Run `pto_gen`, `cpfind`, `cpclean`, `autooptimiser`, `nona` and blending tools.
- [ ] Present structured progress and actionable failures.
- [ ] Add interactive projection, horizon and crop preview.
- [ ] Export JPEG, PNG and TIFF through clear presets.
- [ ] Persist and reopen `.pto` projects.

**Exit criterion:** a normal panorama can be completed through Import → Align →
Preview → Export without opening the classic expert interface.

## Phase 4 — Advanced editing and ecosystem

- [ ] Native control-point inspection and editing.
- [ ] Masks, lens calibration and exposure/HDR workflows.
- [ ] Batch queue and background processing.
- [ ] Crash diagnostics and reproducible support bundles.
- [ ] Plugin or automation interfaces.
