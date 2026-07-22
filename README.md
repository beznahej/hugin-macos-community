# Hugin macOS Community

An **unofficial, macOS-focused community fork and distribution effort** for the
[Hugin Panorama Stitcher](https://hugin.sourceforge.io/).

The immediate goal is to make Hugin dependable on modern Macs—especially Apple
Silicon—before introducing a simpler, native Mac user experience.

> [!IMPORTANT]
> This project is not affiliated with or endorsed by the upstream Hugin project.
> Hugin remains maintained upstream on SourceForge. Copyright in upstream code
> remains with the original Hugin contributors.

## Why this project exists

Hugin has a mature panorama-processing engine, but the macOS build and release
experience has fallen behind current Apple platforms. This project focuses on:

- reproducible `arm64` and `x86_64` builds;
- signed and notarized macOS application bundles;
- dependency and runtime-library cleanup;
- regression tests for the panorama pipeline;
- a streamlined SwiftUI/AppKit front end that preserves `.pto` compatibility;
- contributing generally useful fixes back to upstream.

## Product direction

We will preserve Hugin's established C++ engine and command-line tools while
adding a Mac-native workflow:

1. **Import** images from Finder or Photos.
2. **Align** automatically with visible progress and diagnostics.
3. **Preview** projection, horizon and crop.
4. **Export** using clear presets, with advanced controls available on demand.

Advanced users should retain access to control points, masks, lens parameters,
batch processing and the classic Hugin interface.

## Status

This repository is in the **bootstrap phase**. The first deliverables are:

- project governance and upstream-attribution documents;
- macOS architecture and product-design proposals;
- a reproducible upstream-fetch workflow;
- a reproducible upstream snapshot import workflow;
- build and packaging scaffolding;
- an initial backlog for Apple Silicon, wxWidgets, signing and notarization.

See [First Deliverables](docs/first-deliverables.md) and [Roadmap](ROADMAP.md).

## Upstream

- Project: <https://hugin.sourceforge.io/>
- Source repository: <https://sourceforge.net/p/hugin/hugin/>
- SourceForge Mercurial clone:
  `http://hg.code.sf.net/p/hugin/hugin`

See [UPSTREAM.md](UPSTREAM.md) for the synchronization and contribution policy.
See [Upstream Import Procedure](docs/upstream-import.md) for the reproducible
snapshot workflow.

## Licensing

Hugin is historically licensed under the GNU General Public License, version 2
or later. New source files in this repository should use the SPDX identifier:

```text
SPDX-License-Identifier: GPL-2.0-or-later
```

See [LICENSE](LICENSE), [NOTICE](NOTICE), and [CONTRIBUTING.md](CONTRIBUTING.md).
