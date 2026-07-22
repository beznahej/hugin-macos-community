# Architecture Proposal

## Principles

1. **Preserve the engine.** Hugin's established geometry, optimization and rendering pipeline should not be rewritten merely to modernize the UI.
2. **Separate orchestration from processing.** The native application manages projects, progress and user interaction; Hugin tools perform panorama work.
3. **Keep `.pto` compatibility.** Projects should remain portable to classic Hugin and its command-line tooling.
4. **Make failures diagnosable.** Every pipeline stage should expose its command, exit status, structured progress and logs.
5. **Keep upstream synchronization practical.** Mac-specific code should avoid invasive changes to portable engine code.

## Proposed layers

```text
┌──────────────────────────────────────────────────────────────┐
│ SwiftUI/AppKit application                                  │
│ Import · Project browser · Preview · Crop · Export · Errors │
├──────────────────────────────────────────────────────────────┤
│ macOS orchestration layer                                   │
│ Project state · Process runner · Progress parser · Cache     │
├──────────────────────────────────────────────────────────────┤
│ Hugin CLI pipeline                                          │
│ pto_gen · cpfind · cpclean · autooptimiser · pano_modify    │
│ nona · enblend · enfuse · hugin_executor                    │
├──────────────────────────────────────────────────────────────┤
│ Hugin/libpano engine and bundled runtime dependencies        │
└──────────────────────────────────────────────────────────────┘
```

## Process boundary

The first native UI should invoke the existing command-line tools rather than linking the entire engine directly into Swift. This provides crash isolation, easier upstream synchronization, compatibility with existing workflows, observable commands and independent testing of engine and interface.

A future in-process bridge should be considered only where latency or interactivity requires it.

## Project state

The application owns a non-destructive project package:

```text
ProjectName.huginproject/
├── project.pto
├── manifest.json
├── originals/            # references or security-scoped bookmarks
├── working/
├── previews/
├── exports/
└── diagnostics/
```

Original images remain untouched. Security-scoped bookmarks support sandbox-compatible access to user-selected files.

## Distribution model

The release should contain one principal app and internal helper tools. Users should not need Homebrew or a compiler. Developer builds may consume Homebrew initially, but release builds must use a locked, self-contained dependency set.

## Initial technical decisions

- SwiftUI for the workflow shell, with AppKit where mature Mac controls are required.
- An actor-backed process runner for cancellation, output capture and serialized project mutations.
- Structured adapters around Hugin CLI output rather than exposing raw logs as the normal UI.
- Proxy-resolution previews before full-resolution remapping and blending.
- CMake for upstream engine builds; Xcode/Swift Package Manager for the native shell.
- GitHub Actions for build checks, with signing/notarization enabled only in protected release workflows.
