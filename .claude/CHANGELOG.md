# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-04-17

### Changed
- Updated README installer command to use the pinned `v0.2.1` installer endpoint.
- Removed remaining legacy naming in installer-adjacent repository files.

## [0.2.0] - 2026-03-03

### Added
- Implicit orchestrator model: four-intention cycle (`/hello` → `/new-task` → `/do-task` → `/open-pr`); the legacy orchestrator command was removed
- Auto-version bump workflow for automatic semantic versioning on PR merge
- Self-bootstrapping RL infrastructure detection
- Session persistence with GitHub-first model
- Integration test script (`.claude/scripts/test-harness.sh`)

[Unreleased]: https://github.com/damienstanton/harness-kit/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/damienstanton/harness-kit/releases/tag/v0.2.1
[0.2.0]: https://github.com/damienstanton/harness-kit/releases/tag/v0.2.0
