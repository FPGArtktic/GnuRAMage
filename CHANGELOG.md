# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI: ShellCheck (severity `warning`) and the test suite on Ubuntu,
  Debian bookworm and Arch Linux; documentation build with `mkdocs --strict`.
- Release workflow: on `v*` tags, verifies the tag against the script version, runs
  lint and tests, publishes `gramage.sh`, `GnuRAMage.ini` and `SHA256SUMS`.
- Project documentation (MkDocs Material) with architecture, sequence, activity and
  state diagrams; published on Read the Docs.
- `CHANGELOG.md`, `.editorconfig`, `.shellcheckrc`, Dependabot for Actions.

### Changed
- README rewritten: badges, diagram, configuration and CLI reference, honest
  statement of 1.0.0 limitations. Download instructions now use
  `raw.githubusercontent.com` URLs (the previous `blob` URLs returned HTML).

### Planned for 1.1.0 (see *Known issues* and *Roadmap* in the documentation)
- Refuse sync-back when the RAM directory is empty, lacks the sentinel file, or is
  not on tmpfs/ramfs (`require_ramfs`).
- Signal-driven wait loop usable under systemd/nohup (no stdin dependency);
  SIGTERM/SIGINT perform a final sync and exit.
- Path normalisation; `rsync` used for the initial copy with the same exclude list
  as the sync-back; top-level dotfiles included.
- Rewritten INI parser (exact key match, paths with spaces, no pattern filtering by
  keyword).
- `verify_checksums` wired to `rsync --checksum`.
- `mktemp` for temporary files; `flock` instance lock.
- `--version`, `--sync-now`, `SIGUSR1` → immediate sync; systemd unit in `contrib/`.
- Test suite migrated to bats-core with temporary directories and regression tests
  for every defect listed under *Known issues* in the documentation.

## [1.0.0] - 2025-05-30

### Added
- Initial release: INI configuration, initial copy to RAM disk, periodic
  `rsync --delete` sync-back, exclude patterns, dry-run, one-time mode, leveled
  logging to console and files, generated worker scripts, custom test suite.

[Unreleased]: https://github.com/FPGArtktic/GnuRAMage/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/FPGArtktic/GnuRAMage/releases/tag/v1.0.0
