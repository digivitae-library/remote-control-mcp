#!/bin/bash
# Remote Control MCP - Installation Script
# Installs RCM (remote-control-mcp) with all platform directories
# Supports Linux and macOS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${CYAN}"
    echo "  ============================================================"
    echo "         Remote Control MCP - RCM Installation Wizard         "
    echo "  ============================================================"
    echo -e "${NC}"
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result=""
    echo -en "  ${prompt} ${YELLOW}[${default}]${NC}: "
    read -r result
    if [ -z "$result" ]; then
        result="$default"
    fi
    echo "$result"
}

detect_platform() {
    local os=$(uname -s)
    local arch=$(uname -m)
    
    case "$os" in
        Linux)
            case "$arch" in
                x86_64)  echo "linux-x64" ;;
                i686|i386) echo "linux-x86" ;;
                aarch64) echo "linux-arm64" ;;
                *) echo "linux-x64" ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64) echo "macos-x64" ;;
                arm64)  echo "macos-arm64" ;;
                *)      echo "macos-arm64" ;;
            esac
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

find_bin_root() {
    local script_dir="$1"
    local known_platforms="windows-x86 windows-x64 windows-arm64 linux-x86 linux-x64 linux-arm64 macos-x64 macos-arm64"
    
    for p in $known_platforms; do
        if [ -d "$script_dir/$p/worker" ]; then
            echo "$script_dir"
            return
        fi
    done
    
    local parent=$(dirname "$script_dir")
    for p in $known_platforms; do
        if [ -d "$parent/$p/worker" ]; then
            echo "$parent"
            return
        fi
    done
    
    echo "$script_dir"
}

# ─── Main Installation Flow ─────────────────────────────────────────

print_banner

PLATFORM=$(detect_platform)
if [ "$PLATFORM" = "unknown" ]; then
    echo -e "  ${RED}ERROR: Unsupported platform.${NC}"
    exit 1
fi

echo -e "  Detected platform: ${GREEN}${PLATFORM}${NC}"
echo -e "  OS: $(uname -s) $(uname -r)"
echo -e "  Architecture: $(uname -m)"
echo ""

# Determine bin root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_ROOT=$(find_bin_root "$SCRIPT_DIR")
echo -e "  Source directory: ${BIN_ROOT}"
echo ""

# Step 1: Installation directory
echo -e "  ${BLUE}[1/4]${NC} Installation Directory"
INSTALL_DIR=$(prompt_with_default "Install path" "$SCRIPT_DIR")
echo -e "  -> ${INSTALL_DIR}"
echo ""

# Step 2: Copy all platform directories (if different from source)
echo -e "  ${BLUE}[2/4]${NC} Copying platform directories"
if [ "$INSTALL_DIR" != "$BIN_ROOT" ]; then
    KNOWN_PLATFORMS="windows-x86 windows-x64 windows-arm64 linux-x86 linux-x64 linux-arm64 macos-x64 macos-arm64"
    for p in $KNOWN_PLATFORMS; do
        if [ -d "$BIN_ROOT/$p" ]; then
            rm -rf "$INSTALL_DIR/$p"
            cp -r "$BIN_ROOT/$p" "$INSTALL_DIR/$p"
            echo "    $p -> copied"
        fi
    done
else
    echo "    Install path is same as source, skipping copy."
fi
echo ""

# Step 3: Copy current platform's rcm/ to install root
echo -e "  ${BLUE}[3/4]${NC} Setting up RCM for $PLATFORM"
RCM_SRC="$INSTALL_DIR/$PLATFORM/rcm"
if [ ! -d "$RCM_SRC" ]; then
    RCM_SRC="$BIN_ROOT/$PLATFORM/rcm"
fi
if [ -d "$RCM_SRC" ]; then
    rm -rf "$INSTALL_DIR/rcm"
    cp -r "$RCM_SRC" "$INSTALL_DIR/rcm"
    echo "    RCM copied to $INSTALL_DIR/rcm"
else
    echo -e "    ${YELLOW}Warning: RCM not found for platform $PLATFORM${NC}"
fi
echo ""

# Step 4: Create start.sh
echo -e "  ${BLUE}[4/4]${NC} Creating start script"
cat > "$INSTALL_DIR/start.sh" << 'STARTEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
rcm/remote-control-mcp
STARTEOF
chmod +x "$INSTALL_DIR/start.sh"
echo "    Created: $INSTALL_DIR/start.sh"
echo ""

# Done
echo -e "${GREEN}  ============================================================${NC}"
echo -e "${GREEN}          Installation Complete!                              ${NC}"
echo -e "${GREEN}  ============================================================${NC}"
echo ""
echo -e "  Install location:  ${CYAN}$INSTALL_DIR${NC}"
echo -e "  RCM directory:     ${CYAN}$INSTALL_DIR/rcm${NC}"
echo ""
echo -e "  Start RCM:  ${GREEN}$INSTALL_DIR/start.sh${NC}"
echo -e "  To stop:    Ctrl+C or close terminal"
echo ""
echo "  After starting RCM, use menu [6] to generate distributable Worker packages."
echo ""
