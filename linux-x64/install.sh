#!/bin/bash
# Remote Control MCP - Installation Script
# Installs RCM (remote-control-mcp) with all platform directories
# Supports Linux and macOS

# Colors. Defined with $'...' so the escapes are already expanded and plain
# printf renders them (macOS /bin/sh and bash 3.2 do not expand \033 in echo).
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

KNOWN_PLATFORMS="windows-x86 windows-x64 windows-arm64 linux-x86 linux-x64 linux-arm64 macos-x64 macos-arm64 macos-universal"

WARNINGS=0

warn() {
    printf '    %sWarning: %s%s\n' "$YELLOW" "$1" "$NC"
    WARNINGS=$((WARNINGS + 1))
}

print_banner() {
    printf '\n%s' "$CYAN"
    printf '  ============================================================\n'
    printf '         Remote Control MCP - RCM Installation Wizard         \n'
    printf '  ============================================================\n'
    printf '%s\n' "$NC"
}

# The stdout of this function is captured by the caller with $(...), therefore
# the prompt MUST go to stderr. Printing it to stdout would make the prompt text
# (including the color escapes) part of the returned value and corrupt the
# install path.
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result=""
    printf '  %s %s[%s]%s: ' "$prompt" "$YELLOW" "$default" "$NC" >&2
    read -r result
    if [ -z "$result" ]; then
        result="$default"
    fi
    printf '%s' "$result"
}

detect_platform() {
    local os
    local arch
    os=$(uname -s)
    arch=$(uname -m)

    case "$os" in
        Linux)
            case "$arch" in
                x86_64)    printf 'linux-x64' ;;
                i686|i386) printf 'linux-x86' ;;
                aarch64|arm64) printf 'linux-arm64' ;;
                *)         printf 'linux-x64' ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64) printf 'macos-x64' ;;
                arm64)  printf 'macos-arm64' ;;
                *)      printf 'macos-arm64' ;;
            esac
            ;;
        *)
            printf 'unknown'
            ;;
    esac
}

# Locate the directory that holds the per-platform directories. Supports being
# run from bin/ itself, from a platform directory, or from a source checkout
# root where the platform directories live under bin/.
find_bin_root() {
    local script_dir="$1"
    local parent
    local candidate
    parent=$(dirname "$script_dir")

    for candidate in "$script_dir" "$script_dir/bin" "$parent" "$parent/bin"; do
        for p in $KNOWN_PLATFORMS; do
            if [ -d "$candidate/$p/worker" ] || [ -d "$candidate/$p/rcm" ]; then
                (cd "$candidate" && pwd)
                return
            fi
        done
    done

    printf '%s' "$script_dir"
}

# --- Main Installation Flow -----------------------------------------

print_banner

PLATFORM=$(detect_platform)
if [ "$PLATFORM" = "unknown" ]; then
    printf '  %sERROR: Unsupported platform: %s%s\n' "$RED" "$(uname -s)" "$NC"
    exit 1
fi

printf '  Detected platform: %s%s%s\n' "$GREEN" "$PLATFORM" "$NC"
printf '  OS: %s %s\n' "$(uname -s)" "$(uname -r)"
printf '  Architecture: %s\n' "$(uname -m)"
printf '\n'

# Determine bin root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_ROOT=$(find_bin_root "$SCRIPT_DIR")
printf '  Source directory: %s\n\n' "$BIN_ROOT"

FOUND_ANY=0
for p in $KNOWN_PLATFORMS; do
    if [ -d "$BIN_ROOT/$p" ]; then
        FOUND_ANY=1
        break
    fi
done
if [ "$FOUND_ANY" -eq 0 ]; then
    printf '  %sERROR: No platform directories found under %s%s\n' "$RED" "$BIN_ROOT" "$NC"
    printf '  Run this script from the bin/ directory of a release package.\n'
    exit 1
fi

# Step 1: Installation directory
printf '  %s[1/5]%s Installation Directory\n' "$BLUE" "$NC"
INSTALL_DIR=$(prompt_with_default "Install path" "$SCRIPT_DIR")
if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
    printf '  %sERROR: Cannot create install directory: %s%s\n' "$RED" "$INSTALL_DIR" "$NC"
    exit 1
fi
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
printf '  -> %s\n\n' "$INSTALL_DIR"

# Step 2: Copy all platform directories (if different from source)
printf '  %s[2/5]%s Copying platform directories\n' "$BLUE" "$NC"
if [ "$INSTALL_DIR" != "$BIN_ROOT" ]; then
    COPIED=0
    for p in $KNOWN_PLATFORMS; do
        if [ ! -d "$BIN_ROOT/$p" ]; then
            continue
        fi
        rm -rf "$INSTALL_DIR/$p"
        if cp -R "$BIN_ROOT/$p" "$INSTALL_DIR/$p" 2>/dev/null; then
            printf '    %s -> copied\n' "$p"
            COPIED=$((COPIED + 1))
        else
            warn "failed to copy $p"
        fi
    done
    if [ "$COPIED" -eq 0 ]; then
        warn "no platform directory was copied"
    fi
    if [ -f "$BIN_ROOT/README.md" ]; then
        cp -f "$BIN_ROOT/README.md" "$INSTALL_DIR/README.md" 2>/dev/null
    fi
    if [ -f "$BIN_ROOT/install.sh" ] && [ "$BIN_ROOT/install.sh" != "$INSTALL_DIR/install.sh" ]; then
        cp -f "$BIN_ROOT/install.sh" "$INSTALL_DIR/install.sh" 2>/dev/null
    fi
else
    printf '    Install path is same as source, skipping copy.\n'
fi
printf '\n'

# Step 3: Copy current platform's rcm/ to install root
printf '  %s[3/5]%s Setting up RCM for %s\n' "$BLUE" "$NC" "$PLATFORM"
RCM_SRC=""
for candidate_platform in "$PLATFORM" "macos-universal"; do
    case "$candidate_platform" in
        macos-universal)
            if [ "$(uname -s)" != "Darwin" ]; then
                continue
            fi
            ;;
    esac
    for base in "$INSTALL_DIR" "$BIN_ROOT"; do
        if [ -d "$base/$candidate_platform/rcm" ]; then
            RCM_SRC="$base/$candidate_platform/rcm"
            break
        fi
    done
    if [ -n "$RCM_SRC" ]; then
        break
    fi
done

if [ -n "$RCM_SRC" ]; then
    rm -rf "$INSTALL_DIR/rcm"
    if cp -R "$RCM_SRC" "$INSTALL_DIR/rcm" 2>/dev/null; then
        printf '    RCM copied to %s/rcm\n' "$INSTALL_DIR"
    else
        warn "failed to copy RCM from $RCM_SRC"
    fi
else
    warn "RCM not found for platform $PLATFORM"
fi
printf '\n'

# Step 4: Create start.sh
printf '  %s[4/5]%s Creating start script\n' "$BLUE" "$NC"
cat > "$INSTALL_DIR/start.sh" << 'STARTEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

BIN="rcm/remote-control-mcp"
if [ ! -f "$BIN" ]; then
    case "$(uname -m)" in
        arm64|aarch64) CANDIDATE="rcm/remote-control-mcp-arm64" ;;
        x86_64)        CANDIDATE="rcm/remote-control-mcp-x86_64" ;;
        *)             CANDIDATE="" ;;
    esac
    if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE" ]; then
        BIN="$CANDIDATE"
    fi
fi

if [ ! -f "$BIN" ]; then
    echo "ERROR: remote-control-mcp binary not found in rcm/"
    exit 1
fi

chmod +x "$BIN" 2>/dev/null
exec "./$BIN" "$@"
STARTEOF
chmod +x "$INSTALL_DIR/start.sh" 2>/dev/null
printf '    Created: %s/start.sh\n\n' "$INSTALL_DIR"

# Step 5: Set executable permissions
# Copying from a Windows-built package (or extracting a ZIP) drops the +x bit,
# which makes the OS refuse to start the binaries.
printf '  %s[5/5]%s Setting executable permissions\n' "$BLUE" "$NC"
CHMOD_COUNT=0
make_executable() {
    if [ -f "$1" ]; then
        if chmod +x "$1" 2>/dev/null; then
            CHMOD_COUNT=$((CHMOD_COUNT + 1))
        else
            warn "cannot set +x on $1"
        fi
    fi
}

for f in "$INSTALL_DIR"/rcm/remote-control-mcp*; do
    make_executable "$f"
done
for p in $KNOWN_PLATFORMS; do
    for f in "$INSTALL_DIR/$p"/rcm/remote-control-mcp* \
             "$INSTALL_DIR/$p"/worker/supervisor* \
             "$INSTALL_DIR/$p"/worker/worker*; do
        make_executable "$f"
    done
done
make_executable "$INSTALL_DIR/start.sh"
make_executable "$INSTALL_DIR/install.sh"
printf '    %s file(s) marked executable\n\n' "$CHMOD_COUNT"

# Done
printf '%s  ============================================================%s\n' "$GREEN" "$NC"
printf '%s          Installation Complete!                              %s\n' "$GREEN" "$NC"
printf '%s  ============================================================%s\n' "$GREEN" "$NC"
printf '\n'
printf '  Install location:  %s%s%s\n' "$CYAN" "$INSTALL_DIR" "$NC"
printf '  RCM directory:     %s%s/rcm%s\n' "$CYAN" "$INSTALL_DIR" "$NC"
printf '\n'
printf '  Start RCM:  %s%s/start.sh%s\n' "$GREEN" "$INSTALL_DIR" "$NC"
printf '  To stop:    Ctrl+C or close terminal\n'
printf '\n'
printf '  After starting RCM, use the "Generate distributable Worker packages" menu entry.\n'
if [ "$WARNINGS" -gt 0 ]; then
    printf '\n  %s%s warning(s) reported above.%s\n' "$YELLOW" "$WARNINGS" "$NC"
fi
printf '\n'
