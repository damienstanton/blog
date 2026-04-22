<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: check-update
description: Check for newer harness-kit versions and offer to update.
---
# Check for Updates

Check whether a newer version of the harness-kit framework is available and offer to update.

## When to Use

- Periodically checking if the framework has been updated
- Before starting a new feature, to ensure you're on the latest version
- After hearing about a new release

## Phase 1: Read Installed Version

Look for `.claude/.harness-version` in the workspace root. This file is written by the install scripts or auto-created by `/hello` and `/check-update` and contains:

```json
{
  "version": "0.1.0",
  "installed_at": "2026-02-25T10:30:00Z",
  "installed_from": "v0.1.0"
}
```

If the file does not exist, proceed to Phase 2 — the version file will be auto-created after querying the latest release.

## Phase 2: Query Latest Release

Determine the latest available version from GitHub. Try these methods in order:

### Method 1: gh CLI (preferred)

```bash
gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/releases/latest --jq '.tag_name'
```

If this succeeds, also fetch the release date and release notes URL.

### Method 2: git ls-remote (fallback)

```bash
git ls-remote --tags --sort=-v:refname https://github.com/${CORE_FLOW_REPO:-damienstanton/harness-kit}.git 'v*' | head -1
```

Parse the tag name from the output. Release date will be unavailable with this method.

**If neither method returns a version:**

> Could not determine the latest release. No releases or version tags found.
>
> This may mean no tagged releases have been created yet.

Stop here.

### Auto-Create Version File (When Missing)

If Phase 1 found no version file **and** Phase 2 successfully retrieved a latest release tag, auto-create `.claude/.harness-version` before proceeding to Phase 3:

1. Query the tag's commit SHA:

```bash
gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/git/ref/tags/<tag> --jq '.object.sha'
```

If the SHA query fails, use `"unknown"` as the SHA value.

2. Write the version file:

```json
{
  "auto_detected": true,
  "installed_at": "<current ISO 8601 UTC timestamp>",
  "installed_from": {
    "ref": "<tag>",
    "sha": "<commit SHA or \"unknown\">"
  },
  "version": "<tag without leading v>"
}
```

The `auto_detected` field distinguishes this from installer-created files. The install scripts do not set this field.

3. Use the auto-created version as the installed version for Phase 3 comparison.

If Phase 2 also failed (no releases found), do NOT create the file — stop as described above.

## Phase 3: Compare and Present

Strip any leading `v` prefix and compare the semver strings.

### Auto-detected (first run, no prior version file)

When the version file was just auto-created in Phase 2, the installed version equals the latest release:

```
harness-kit version check
  Installed:  v0.2.0 (auto-detected from latest release)
  Latest:     v0.2.0 (released 2026-02-25)
  Status:     Up to date (version file auto-created)

No action needed.
```

### Up to date

```
harness-kit version check
  Installed:  v0.2.0 (installed 2026-02-25)
  Latest:     v0.2.0 (released 2026-02-25)
  Status:     Up to date

No action needed.
```

### Update available

```
harness-kit version check
  Installed:  v0.1.0 (installed 2026-02-20)
  Latest:     v0.2.0 (released 2026-02-25)
  Status:     Update available
```

When an update is available, proceed to Phase 4.

### Ahead of latest release

If the installed version is newer than the latest release (e.g., installed from a pre-release branch):

```
harness-kit version check
  Installed:  v0.3.0-dev (installed 2026-02-25)
  Latest:     v0.2.0 (released 2026-02-25)
  Status:     Ahead of latest release (installed from: main)
```

No action needed.

## Phase 4: Show Update Details (Only When Update Available)

### Step 1: Fetch CHANGELOG diff

Try to fetch the CHANGELOG between versions:

```bash
gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/contents/CHANGELOG.md --jq '.content' | base64 --decode
```

If the CHANGELOG exists, extract and display only the sections between the installed version and the latest version. Show the relevant "Added", "Changed", "Fixed" entries.

If the CHANGELOG is not available, skip this step.

### Step 2: Present update option

Use AskUserQuestion to offer the update:

> **Update available: v0.1.0 → v0.2.0**
>
> [CHANGELOG entries if available]
>
> Options:
> - **Update now** — Run the install script with the latest version
> - **Show update command** — Print the command to run manually
> - **Skip** — Do nothing

### If "Update now"

Run the install script targeting the latest version:

```bash
CORE_FLOW_REF=<latest_version> bash <(gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/contents/.claude/scripts/install.sh?ref=<latest_version> -q '.content' | base64 --decode)
```

After the install completes, re-read `.claude/.harness-version` and confirm the update succeeded.

### If "Show update command"

Print the command for the user to copy and run in their terminal:

```
To update, run:

  CORE_FLOW_REF=v0.2.0 bash <(gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/contents/.claude/scripts/install.sh?ref=v0.2.0 -q '.content' | base64 --decode)
```

Also show the PowerShell equivalent for Windows users:

```
On Windows (PowerShell):

  $env:CORE_FLOW_REF = "v0.2.0"
  $s = gh api repos/$($env:CORE_FLOW_REPO ?? "damienstanton/harness-kit")/contents/.claude/scripts/install.ps1?ref=v0.2.0 --jq '.content'
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($s)) | iex
```

### If "Skip"

> Staying on v0.1.0. You can check again anytime with `/check-update`.

## Notes

- The terminal scripts (`.claude/scripts/check-update.sh` and `.claude/scripts/check-update.ps1`) provide the same check for CI or terminal use.
- The repo slug defaults to `damienstanton/harness-kit`. Users who have forked the repo can override this by setting the `CORE_FLOW_REPO` environment variable before running the scripts.
