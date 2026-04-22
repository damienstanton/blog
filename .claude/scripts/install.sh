#!/usr/bin/env bash
# harness-kit Install Script (macOS/Linux)
# Installs or updates the harness-kit framework in the current directory.

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

CORE_FLOW_REF="${CORE_FLOW_REF:-main}"
CORE_FLOW_REPO="${CORE_FLOW_REPO:-damienstanton/harness-kit}"

# =============================================================================
# Color output
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}INFO:${NC} $*"; }
success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*" >&2; }
fatal() { error "$*"; exit 1; }

# =============================================================================
# Prerequisite Checking
# =============================================================================

check_prerequisites() {
    info "Checking prerequisites..."

    local missing=()

    # git is required
    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    # gh is optional but preferred
    if ! command -v gh &>/dev/null; then
        warn "gh CLI not found — install method will use git clone fallback"
        warn "For better performance and private repo support, install gh:"
        warn "  macOS:  brew install gh"
        warn "  Linux:  See https://cli.github.com/manual/installation"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required prerequisites: ${missing[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  macOS:  brew install ${missing[*]}"
        echo "  Debian/Ubuntu: sudo apt-get install ${missing[*]}"
        echo "  Fedora/RHEL: sudo dnf install ${missing[*]}"
        echo "  Arch: sudo pacman -S ${missing[*]}"
        exit 1
    fi

    success "Prerequisites OK"
}

# =============================================================================
# Source Detection
# =============================================================================

# Detect if we're being run from a git clone of the harness-kit repo or need to clone
detect_source() {
    # Determine the directory containing this script
    local script_path script_dir repo_root origin_url

    script_path="${BASH_SOURCE[0]:-$0}"
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"

    # Try to find the git repo root that contains this script
    if repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        # If we have a git repo, check whether its origin matches the expected CORE_FLOW_REPO
        if origin_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)"; then
            case "$origin_url" in
                *"$CORE_FLOW_REPO"*)
                    SOURCE_MODE="local"
                    SOURCE_DIR="$repo_root"
                    info "Detected local harness-kit source from git clone: $SOURCE_DIR"
                    return
                    ;;
            esac
        fi
    fi

    # Fallback: treat as remote install (will clone to a temporary directory)
    SOURCE_MODE="remote"
    info "Detected remote installation (will clone from GitHub)"
}

# =============================================================================
# Clone Source
# =============================================================================

clone_source() {
    local tmp_dir
    tmp_dir=$(mktemp -d -t harness-kit-XXXXXX)

    info "Cloning $CORE_FLOW_REPO (ref: $CORE_FLOW_REF) to $tmp_dir..."

    # NOTE: CORE_FLOW_REF must be a branch name or tag (not a SHA)
    # SHA pinning not supported with shallow clones
    if git clone --depth 1 --branch "$CORE_FLOW_REF" \
        "https://github.com/$CORE_FLOW_REPO.git" "$tmp_dir" 2>/dev/null; then
        SOURCE_DIR="$tmp_dir"
        success "Cloned successfully"
    else
        fatal "Failed to clone repository. Ensure CORE_FLOW_REF is a valid branch or tag (SHAs not supported)."
    fi
}

# =============================================================================
# File Operations
# =============================================================================

# Read version from SOURCE_DIR/.claude/VERSION
read_version() {
    local version_file="$SOURCE_DIR/.claude/VERSION"
    if [ -f "$version_file" ]; then
        cat "$version_file" | tr -d '\n\r'
    else
        echo "unknown"
    fi
}

# Copy files with preservation rules
install_files() {
    local src="$SOURCE_DIR"
    local dst="."

    info "Installing framework files..."

    # Create directories if they don't exist
    mkdir -p .claude/features .claude/artifacts .claude/context

    # Always overwrite: framework core (remove first to avoid mixed versions)
    info "  Copying framework core..."
    rm -rf .claude/agents .claude/skills .claude/specs .claude/rules .claude/scripts
    cp -R "$src/.claude/agents" "$dst/.claude/"
    cp -R "$src/.claude/skills" "$dst/.claude/"
    cp -R "$src/.claude/specs" "$dst/.claude/"
    cp -R "$src/.claude/rules" "$dst/.claude/"
    cp -R "$src/.claude/scripts" "$dst/.claude/"
    cp "$src/.claude/settings.json" "$dst/.claude/"
    cp "$src/.claude/README.md" "$dst/.claude/"
    cp "$src/.claude/VERSION" "$dst/.claude/"
    cp "$src/.claude/CHANGELOG.md" "$dst/.claude/"

    # Copy root docs (optional — warn if missing)
    info "  Copying root docs..."
    for doc in CLAUDE.md AGENTS.md README.md start_here.md ACADEMIC_NOTICE.md; do
        if [ -f "$src/$doc" ]; then
            cp "$src/$doc" "$dst/"
        else
            warn "$doc not found in source; skipping"
        fi
    done

    # Copy template profile only if it doesn't exist
    if [ ! -f "$dst/.claude/profiles/_template.yaml" ]; then
        info "  Copying profile template..."
        mkdir -p "$dst/.claude/profiles"
        if [ -f "$src/.claude/profiles/_template.yaml" ]; then
            cp "$src/.claude/profiles/_template.yaml" "$dst/.claude/profiles/"
        else
            warn "Profile template _template.yaml not found in source; skipping"
        fi
    else
        info "  Preserving existing profile template"
    fi

    # Preserve user files (never overwrite):
    # - .claude/profiles/* (except _template.yaml)
    # - .claude/features/
    # - .claude/artifacts/
    # - .claude/context/
    # - .claude/.harness-version

    success "Files installed"
}

# =============================================================================
# Version File
# =============================================================================

write_version_file() {
    local version
    version=$(read_version)

    local version_file=".claude/.harness-version"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    info "Writing version file..."

    # Determine installed_from format
    if [[ "$CORE_FLOW_REF" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Tag format
        cat > "$version_file" <<EOF
{
  "version": "$version",
  "installed_at": "$timestamp",
  "installed_from": "$CORE_FLOW_REF"
}
EOF
    else
        # Branch or SHA format
        local sha="unknown"
        if [ -d "$SOURCE_DIR/.git" ]; then
            sha=$(cd "$SOURCE_DIR" && git rev-parse HEAD 2>/dev/null || echo "unknown")
        fi

        cat > "$version_file" <<EOF
{
  "version": "$version",
  "installed_at": "$timestamp",
  "installed_from": {
    "ref": "$CORE_FLOW_REF",
    "sha": "$sha"
  }
}
EOF
    fi

    success "Version file written: $version_file"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "harness-kit Installer"
    echo "==================="
    echo ""

    check_prerequisites
    detect_source

    if [ "$SOURCE_MODE" = "remote" ]; then
        clone_source
        CLEANUP_NEEDED=true
    else
        CLEANUP_NEEDED=false
    fi

    install_files
    write_version_file

    # Make install scripts executable
    chmod +x .claude/scripts/*.sh 2>/dev/null || true

    if [ "$CLEANUP_NEEDED" = true ]; then
        info "Cleaning up temporary files..."
        rm -rf "$SOURCE_DIR"
    fi

    echo ""
    success "harness-kit installed successfully!"
    echo ""
    # Read version from installed destination (SOURCE_DIR may be cleaned up)
    if [ -f ".claude/VERSION" ]; then
        echo "Version: $(cat .claude/VERSION | tr -d '\n\r')"
    else
        echo "Version: unknown"
    fi
    echo "Ref:     $CORE_FLOW_REF"
    echo ""
    echo "Next steps:"
    echo "  1. Start a Claude Code session: claude"
    echo "  2. Type: /hello            (to orient yourself)"
    echo "     Or:   /new-task <description>  (to plan a feature)"
    echo ""
}

main "$@"
