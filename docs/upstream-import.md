# Upstream Import Procedure

This project uses periodic vendor snapshots from the SourceForge Mercurial
`default` branch as the initial GitHub baseline.

The full SourceForge repository remains authoritative. The downstream GitHub
repository should keep imported upstream source mechanically separate from
macOS-specific fixes, packaging work and native UI work.

## Import Model

- `vendor/hugin/` is an ignored Mercurial working copy used for fetching and
  updating upstream.
- `upstream/hugin/` is the tracked source snapshot produced from the Mercurial
  working copy.
- `upstream/hugin/UPSTREAM-SNAPSHOT` records the upstream URL, branch, revision,
  full revision, import timestamp and import script.

This chooses the periodic vendor snapshot path rather than preserving complete
Mercurial history in Git. That keeps the first public baseline easy to review and
lets later commits isolate downstream macOS changes.

## Prerequisites

```bash
brew install mercurial
```

## Reproduce The Snapshot

From the repository root:

```bash
./scripts/import-upstream-snapshot.sh
```

The command will:

1. clone or update `http://hg.code.sf.net/p/hugin/hugin` into `vendor/hugin/`;
2. update the working copy to the `default` branch;
3. export a clean archive into `upstream/hugin/`;
4. write `upstream/hugin/rev.txt` for upstream CMake archive builds;
5. write `upstream/hugin/UPSTREAM-SNAPSHOT`.

## Commit Discipline

The upstream snapshot commit must contain only:

- files exported from upstream Hugin;
- the generated `UPSTREAM-SNAPSHOT` provenance file.
- the generated `rev.txt` file required by upstream CMake archive builds.

Downstream changes should be separate commits after the baseline lands.

## Update Discipline

Future upstream refreshes should follow the same process:

```bash
./scripts/import-upstream-snapshot.sh
git status --short
git add upstream/hugin
git commit -m "vendor: import Hugin upstream snapshot <revision>"
```

The exact revision should come from `upstream/hugin/UPSTREAM-SNAPSHOT`.
