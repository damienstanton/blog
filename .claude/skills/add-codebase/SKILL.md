<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: add-codebase
description: Add a git repo or local directory to .claude/context/ for agent reference.
---
# Add Codebase

Add a git repository or local directory to `.claude/context/`, making it available to all agents for inspection during planning and implementation. Remote repos are added as git submodules; local directories are symlinked.

## When to Use

- Adding a reference codebase that agents should consult during development
- Importing a template repository for bootstrap
- Bringing in an internal library or SDK for cross-referencing
- Adding documentation or examples from an external source
- Referencing a local working repository that has no published remote

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<source>` | Yes | Git URL (remote) OR filesystem path (local directory) |
| `<name>` | No | Directory name under `.claude/context/`. Defaults to repo name (remote) or directory basename (local). |
| `--branch <ref>` | No | Remote only. Clone a specific branch or tag. Defaults to the repo's default branch. Ignored for local paths. |
| `--full-history` | No | Remote only. Clone full git history. Default is shallow (`--depth 1`). Ignored for local paths. |

## Phase 1: Validate Input

### 1.1 Parse Arguments

Extract the source and optional name from the user's message. Example invocations:

```
/add-codebase https://github.com/org/my-lib
/add-codebase https://github.com/org/my-lib cool-lib
/add-codebase https://github.com/org/my-lib --branch v2.0
/add-codebase git@github.com:org/my-lib.git --full-history
/add-codebase /Users/me/work/my-private-lib
/add-codebase /Users/me/work/my-private-lib private-lib
/add-codebase ./sibling-project
/add-codebase ../other-repo other
```

### 1.2 Classify Input

Determine whether the source is a **remote URL** or a **local path**:

**Remote URL** — matches any of:
- Starts with `https://`, `http://`, or `git://`
- Starts with `git@`

**Local path** — any of:
- Starts with `/` (absolute path)
- Starts with `./` or `../` (explicit relative path)
- Does NOT match the URL patterns above AND exists as a directory on disk (`test -d <source>`)

If the source matches neither category:
> Invalid source: `<source>`. Expected a git URL (e.g., `https://github.com/org/repo`) or a local directory path (e.g., `/path/to/dir` or `./relative/dir`).

### 1.3 Validate Source

**For remote URLs:**
- Check that the URL contains a path component (not just a bare domain)
- If invalid: report the error and suggest the correct format

**For local paths:**

```bash
test -d <source>
```

- If the directory does not exist: report "Directory not found: `<source>`"
- Resolve to absolute path for symlink creation:

```bash
RESOLVED_PATH="$(cd "<source>" && pwd)"
```

**Path safety check:** If the resolved path is a system directory (`/etc`, `/var`, `/usr`) or an ancestor of the workspace root, warn the user before proceeding:
> Warning: `<resolved-path>` is outside the workspace hierarchy. Agents will have read access to its contents. Continue?

This prevents accidental exposure of sensitive directories. The check is advisory — the user can override.

### 1.4 Infer Directory Name

If the user didn't provide a name:

**Remote URL:**
- `https://github.com/org/my-lib.git` → `my-lib`
- `https://github.com/org/my-lib` → `my-lib`
- `git@github.com:org/my-lib.git` → `my-lib`

**Local path:**
- `/Users/me/work/my-private-lib` → `my-private-lib`
- `./sibling-project` → `sibling-project`
- `../other-repo` → `other-repo`

### 1.5 Check for Conflicts

```bash
ls .claude/context/<name>/ 2>/dev/null
```

If the directory already exists:
> `.claude/context/<name>/` already exists. Options:
> 1. Choose a different name: `/add-codebase <source> <different-name>`
> 2. Remove the existing entry first (see removal instructions below)

Do NOT overwrite without user confirmation.

## Phase 2: Link Source

### 2.1 Ensure Directory Exists

```bash
mkdir -p .claude/context
```

### 2.2a Add Git Submodule (Remote URL)

Build the command from arguments:

```bash
# Base command
git submodule add <url> .claude/context/<name>

# With branch
git submodule add -b <ref> <url> .claude/context/<name>

# With shallow clone (default)
git submodule add --depth 1 <url> .claude/context/<name>

# With branch AND shallow clone
git submodule add --depth 1 -b <ref> <url> .claude/context/<name>
```

Default behavior is shallow clone (`--depth 1`). Only omit `--depth 1` if the user passes `--full-history`.

**Handle errors:**

- **Authentication error:** Report and suggest checking SSH keys or using HTTPS.
- **Network error:** Report and suggest checking connectivity.
- **Already registered:** The submodule may already be in `.gitmodules`. Report the existing entry and suggest `git submodule update --init`.

### 2.2b Create Symlink (Local Path)

```bash
ln -s "$RESOLVED_PATH" ".claude/context/<name>"
```

After creating the symlink, add the entry to `.gitignore` so the symlinked content is not tracked:

```bash
# Append to .gitignore if not already present (check with and without trailing slash)
if ! grep -qE '^\.claude/context/<name>/?$' .gitignore 2>/dev/null; then
    echo '.claude/context/<name>' >> .gitignore
fi
```

**Handle errors:**

- **Symlink creation failed:** Report the error. Common cause: a file (not directory) already exists at the target path.
- **Path is not a directory:** Report "Source must be a directory, not a file."

## Phase 3: Verify and Analyze

### 3.1 Verify Link

```bash
ls .claude/context/<name>/
```

Confirm files exist in the target directory. For symlinks, also verify the link is valid:

```bash
test -L .claude/context/<name> && test -d .claude/context/<name>
```

### 3.2 Detect Project Type

Scan the root of the newly added context entry for known markers:

| Marker File | Detection |
|-------------|-----------|
| `.harness-kit-template.yaml` | harness-kit template (bootstrappable) |
| `Cargo.toml` | Rust |
| `package.json` | TypeScript / JavaScript |
| `pyproject.toml` | Python |
| `go.mod` | Go |
| `CMakeLists.txt` | C / C++ |
| `Makefile` | C / C++ / Generic |

### 3.3 Read Template Manifest (if present)

If `.harness-kit-template.yaml` exists, read it and extract:
- `name`, `language`, `layer`, `description`
- Any placeholder variables that would need substitution during bootstrap

## Phase 4: Report

### 4.1 List All Context

```bash
ls -1 .claude/context/
```

### 4.2 Present Summary

```
## Codebase Added

✅ **<name>** added to `.claude/context/<name>/`

| Property | Value |
|----------|-------|
| Source | `<url or path>` |
| Link type | submodule (remote) / symlink (local) |
| Branch | `<branch or default>` (remote only) |
| Clone depth | shallow (depth 1) / full history (remote only) |
| Detected type | Rust / Python / TypeScript / unknown |
| Template | Yes (bootstrappable) / No |

### Context Directory
| Directory | Link | Type | Template |
|-----------|------|------|----------|
| `<name>` | submodule | Rust | Yes |
| `<other>` | symlink | Python | No |
| ... | ... | ... | ... |

### Next Steps
- To bootstrap from this template: tell me "Bootstrap from <name>"
- To add another codebase: `/add-codebase <source>`
- To inspect what's available: `ls .claude/context/`
- To remove a submodule: `git rm .claude/context/<name> && git commit -m "Remove <name> context"`
- To remove a symlink: `rm .claude/context/<name>` then remove its `.gitignore` entry: `sed -i.bak '/^\.cursor\/context\/<name>$/d' .gitignore && rm -f .gitignore.bak`
```

## Edge Cases

- **No git repo in workspace:** If the workspace is not a git repository, `git submodule add` will fail for remote URLs. Report: "This workspace is not a git repository. Run `git init` first." Local symlinks still work without git.
- **Submodule already in `.gitmodules`:** Check `.gitmodules` for an existing entry with the same path before attempting to add.
- **Nested submodules:** The added repo may itself contain submodules. Do NOT recurse — only add the top-level repo.
- **Broken symlink:** If the local source directory is moved or deleted after symlinking, the symlink becomes broken. The report phase detects this: `test -L <path> && ! test -d <path>` → warn "Symlink exists but target directory is missing."
- **Relative symlinks:** Always resolve to absolute paths before creating the symlink. Relative symlinks break when the working directory changes.
- **Symlink loops:** If the source directory is a parent or ancestor of the workspace, symlinking it creates a circular reference that agents could traverse infinitely. Detection: check if the workspace root starts with the resolved source path. If so, refuse and report: "Cannot symlink a parent directory of the workspace — this would create a circular reference."
- **`--branch` or `--full-history` with local path:** Silently ignore these flags (they only apply to remote URLs). Do not error.
