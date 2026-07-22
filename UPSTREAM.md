# Upstream Policy

## Authoritative source

The authoritative Hugin source remains the SourceForge Mercurial repository:

```text
https://hg.code.sf.net/p/hugin/hugin
```

This GitHub project is an unofficial downstream focused on modern macOS builds,
packaging and user experience.

## Repository model

The intended long-term branch model is:

- `upstream`: mechanically synchronized snapshots from SourceForge `default`;
- `main`: stable macOS community branch;
- `build/macos-*`: build, packaging and release engineering;
- `ui/native-mac`: native Mac application work.

Until the full upstream history is imported, `scripts/fetch-upstream.sh` creates
a working copy under `vendor/hugin/`, which is intentionally ignored by Git.

## Contribution upstream

Changes that are not specific to this downstream should be proposed to Hugin's
SourceForge project first or in parallel. Examples include:

- correctness fixes in panorama algorithms;
- portable C++ and CMake fixes;
- wxWidgets fixes that benefit other platforms;
- documentation corrections applicable to all systems.

Mac-only signing, notarization, SwiftUI/AppKit integration and Apple platform
packaging may remain downstream, while reusable pieces should still be offered
upstream where practical.

## Attribution

When importing third-party patches:

1. Preserve original authorship where Git permits it.
2. Reference the original commit, patch repository or issue.
3. Record modifications made during adaptation.
4. Confirm license compatibility before merging.
