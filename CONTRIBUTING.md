# Contributing

Thank you for helping improve Hugin on macOS.

## License

Hugin is historically GPL version 2 or later. Unless a file states otherwise,
new source contributions to this repository must be compatible with:

```text
SPDX-License-Identifier: GPL-2.0-or-later
```

By submitting a contribution, you certify that you have the right to provide it
under the repository's license.

## Development rules

- Keep upstream imports separate from downstream changes.
- Include attribution when adapting an external patch.
- Prefer portable fixes and offer them upstream where appropriate.
- Do not commit signing certificates, notarization credentials, Apple IDs,
  provisioning profiles or private test images.
- Add or update tests for behavior changes.
- Include exact reproduction commands for build and runtime defects.

## Commit style

Use focused commits with prefixes such as:

```text
build(mac): ...
fix(wx): ...
fix(bundle): ...
ui(mac): ...
test(pipeline): ...
docs: ...
upstream: import revision ...
```

## Pull requests

A pull request should state:

- problem and user impact;
- architecture(s) and macOS versions tested;
- build commands;
- before/after behavior;
- license and attribution notes;
- upstream submission status when relevant.
