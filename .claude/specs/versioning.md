# Versioning Policy

The harness-kit framework follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) with policies tailored to a framework of specs, agents, commands, and configuration schemas (as opposed to a compiled library with a public API).

## Version Scheme

Versions use the format `MAJOR.MINOR.PATCH`.

### Major (X.0.0)

A major version bump signals breaking changes that require existing users to migrate. Any of the following constitutes a breaking change:

- Removing or renaming a profile schema field that existing `.claude/profiles/*.yaml` files depend on
- Changing artifact JSON schemas (`plan.v1`, `finding.v1`, `manifest.v1`, etc.) in ways that invalidate previously generated artifacts
- Altering the workflow contract (phase ordering, gate semantics, or error-as-data return types) such that existing orchestration logic breaks
- Renaming or removing slash commands that users have integrated into their workflows
- Changing the ticket lifecycle state machine in ways that orphan existing tickets

### Minor (0.X.0)

A minor version bump signals new capabilities that are backward-compatible with existing profiles, artifacts, and workflows:

- Adding new agents to `.claude/agents/`
- Adding new slash commands to `.claude/commands/`
- Adding new specs to `.claude/specs/`
- Adding optional fields to profile schema or artifact schemas
- Adding new governance rules to `.claude/rules/`
- Adding new template bootstrap capabilities
- Extending the polyglot architecture with new language targets

### Patch (0.0.X)

A patch version bump signals fixes that do not change observable behavior:

- Bug fixes in agent prompts or command logic
- Documentation corrections and clarifications
- Prompt improvements that produce better output without changing contracts
- Fixing typos or formatting in specs
- Correcting install script edge cases

## Pre-1.0 Expectations

The starting version is `0.1.0`. While the major version is `0`, the framework is under active development and minor versions may include small breaking changes. Users should pin to a specific version or tag and review the changelog before upgrading.

Once the framework reaches `1.0.0`, the semver contract above is strictly enforced: no breaking changes without a major bump.

## Version File

The canonical version lives in `.claude/VERSION`. This file contains a single line with the semver string (no `v` prefix, no trailing whitespace beyond a newline):

```
0.1.0
```

Install scripts, update checkers, and CI workflows read this file as the source of truth.

## Changelog

All notable changes are recorded in `.claude/CHANGELOG.md`, following the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Every release has a dated section with entries categorized as Added, Changed, Deprecated, Removed, Fixed, or Security.

## Automated Release Process

Releases are fully automated via GitHub Actions. When a PR merges to main, the `auto-version-bump.yml` workflow determines the bump type, updates the version and changelog, commits, tags, and creates a GitHub Release.

### PR Labels

The bump type is controlled by labels on the pull request:

| Label | Bump | Example |
|-------|------|---------|
| *(no semver label)* | patch | 0.1.0 → 0.1.1 |
| `semver:patch` | patch | 0.1.0 → 0.1.1 |
| `semver:minor` | minor | 0.1.1 → 0.2.0 |
| `semver:major` | major | 0.2.0 → 1.0.0 |
| `semver:skip` | *(none)* | no version change |

If no `semver:*` label is present, the default is a **patch** bump. Use `semver:skip` for documentation-only or CI-only changes that should not create a release. If multiple `semver:*` labels are present, `semver:skip` supersedes all other semver labels (no version change); otherwise, major takes precedence over minor over patch.

These labels must exist in the GitHub repository (Settings -> Labels). The workflow defaults to patch if no recognized label is found, so missing labels degrade gracefully.

### Workflow Chain

```
PR merges to main
  → auto-version-bump.yml
    → reads semver label (default: patch)
    → bumps .claude/VERSION
    → moves [Unreleased] changelog entries to new dated section
    → commits "release: vX.Y.Z" and pushes to main
    → creates git tag vX.Y.Z
    → creates GitHub Release with changelog notes
```

The existing `release.yml` remains as a fallback for manual VERSION bumps. It triggers independently when `.claude/VERSION` changes on main via a direct push.

### What PR Authors Must Do

Add changelog entries under `## [Unreleased]` in `.claude/CHANGELOG.md` using the appropriate category (Added, Changed, Deprecated, Removed, Fixed, Security). The automation handles moving these entries into a versioned section, updating comparison links, and creating the release. No manual version bumps, tags, or release notes are needed.

### What the Automation Does

1. Reads the `semver:*` label from the merged PR (default: patch)
2. Increments the version in `.claude/VERSION` accordingly
3. Moves `[Unreleased]` entries in `.claude/CHANGELOG.md` to a `[X.Y.Z] - YYYY-MM-DD` section
4. Adds a fresh empty `[Unreleased]` section
5. Updates the comparison links at the bottom of the changelog
6. Commits with message `release: vX.Y.Z`
7. Creates git tag `vX.Y.Z` and pushes it
8. Creates a GitHub Release with the changelog section as release notes

## Manual Release Process (Fallback)

If the automated workflow is unavailable or needs to be bypassed, releases can be created manually:

1. Update `.claude/VERSION` with the new version number
2. Move the `[Unreleased]` section in `.claude/CHANGELOG.md` to a new dated section for the version
3. Add a fresh empty `[Unreleased]` section
4. Update the comparison links at the bottom of `.claude/CHANGELOG.md`
5. Commit with message `release: vX.Y.Z`
6. Push the commit to main: `git push origin main`

The `release.yml` workflow triggers when `.claude/VERSION` changes on a push to main. It creates the git tag and GitHub Release automatically via `gh release create`. If that workflow fails, create the release manually: `gh release create vX.Y.Z --notes-file <notes>` (this also creates the tag if it does not exist).
