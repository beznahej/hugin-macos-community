# First Deliverables

## Deliverable 1: Upstream source baseline

Create a provenance-preserving baseline from SourceForge `default` and record:

- upstream URL;
- Mercurial revision;
- import date;
- conversion/import procedure;
- any excluded generated or binary content.

**Acceptance criteria**

- The baseline can be reproduced from documented commands.
- The upstream revision appears in build metadata.
- No downstream functional changes are mixed into the import commit.

**Implementation path**

- Use `scripts/import-upstream-snapshot.sh` to export SourceForge `default` into
  `upstream/hugin/`.
- Record source metadata in `upstream/hugin/UPSTREAM-SNAPSHOT`.
- Keep the import commit mechanically separate from all macOS downstream work.

## Deliverable 2: Apple Silicon build audit

Run a clean `arm64` build and classify every failure into:

- compiler/language compatibility;
- dependency discovery;
- architecture assumptions;
- wxWidgets API compatibility;
- runtime-library bundling;
- application startup/runtime behavior.

**Acceptance criteria**

- Failures are represented as independently actionable issues.
- Each issue includes the command, log excerpt and affected source path.
- Known third-party macOS patches are reviewed and attributed.

The first audit note lives at
`docs/build-audits/apple-silicon-2026-07-22.md`.
The initial Homebrew dependency manifest lives at
`deps/macos/homebrew-formulae.txt`.

## Deliverable 3: Reproducible development build

Provide one command that creates a local development bundle:

```bash
./scripts/macos/build-dev.sh
```

**Acceptance criteria**

- No hardcoded Intel Homebrew prefix.
- No `-march=core2` or `LIBOMP_ARCH=32e` assumptions.
- Build architecture is explicit and defaults to the host architecture.
- Dependency versions are visible and repeatable.

## Deliverable 4: Panorama regression fixture

Add a small, redistributable image set and expected pipeline metadata.

**Acceptance criteria**

- Alignment completes in CI.
- The resulting project has a minimum number of valid control points.
- Optimization and rendering tools exit successfully.
- Output dimensions and basic image-integrity checks are deterministic within documented tolerances.

## Deliverable 5: Mac bundle validation

Add a script that checks:

- unresolved dylibs;
- absolute Homebrew paths;
- mixed or incorrect architectures;
- code-signing state;
- nested executable signing;
- application launch and CLI helper execution.

## Deliverable 6: Native UX prototype

Build a non-destructive SwiftUI prototype for:

1. image import;
2. thumbnail sequence review;
3. alignment progress;
4. panorama preview and crop;
5. export preset selection.

The prototype may initially use mocked pipeline output, but process boundaries and state models must be designed for the real Hugin CLI tools.
