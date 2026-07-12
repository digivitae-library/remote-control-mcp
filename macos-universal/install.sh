#!/bin/bash
# Remote Control MCP - Installation Script
# Supports Linux and macOS
# Provides text-based UI to configure and generate startup scripts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

INSTALL_DIR=""
SERVICE_PORT=""
WORKER_NAME=""
AUTO_RESTART=""
CHECK_INTERVAL=""

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         Remote Control MCP - Installation Wizard        ║"
    echo "║                                                         ║"
    echo "║   A dual-architecture MCP service for AI Agents         ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[$1/$2]${NC} $3"
    echo "────────────────────────────────────────────────────────────"
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
                *) echo "linux-x64" ;;
            esac
            ;;
        Darwin)
            echo "macos-universal"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ─── Main Installation Flow ─────────────────────────────────────────

print_banner

PLATFORM=$(detect_platform)
echo -e "  Detected platform: ${GREEN}${PLATFORM}${NC}"
echo -e "  OS: $(uname -s) $(uname -r)"
echo -e "  Architecture: $(uname -m)"

if [ "$PLATFORM" = "unknown" ]; then
    echo -e "${RED}ERROR: Unsupported platform.${NC}"
    exit 1
fi

# Step 1: Installation directory
print_step 1 5 "Installation Directory"
INSTALL_DIR=$(prompt_with_default "Install path" "/opt/remote-control-mcp")

# Step 2: Service port
print_step 2 5 "Service Configuration"
SERVICE_PORT=$(prompt_with_default "MCP service port" "18888")
WORKER_NAME=$(prompt_with_default "Worker name" "mcp-worker-1")

# Step 3: Supervisor settings
print_step 3 5 "Supervisor Settings"
AUTO_RESTART=$(prompt_with_default "Auto-restart on crash (true/false)" "true")
CHECK_INTERVAL=$(prompt_with_default "Health check interval (seconds)" "5")

# Step 4: Confirm
print_step 4 5 "Configuration Summary"
echo -e "  ${CYAN}Install Directory:${NC}  $INSTALL_DIR"
echo -e "  ${CYAN}Platform:${NC}           $PLATFORM"
echo -e "  ${CYAN}Service Port:${NC}       $SERVICE_PORT"
echo -e "  ${CYAN}Worker Name:${NC}        $WORKER_NAME"
echo -e "  ${CYAN}Auto Restart:${NC}       $AUTO_RESTART"
echo -e "  ${CYAN}Check Interval:${NC}     ${CHECK_INTERVAL}s"
echo ""
echo -en "  Proceed with installation? ${YELLOW}[Y/n]${NC}: "
read -r confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Step 5: Install
print_step 5 5 "Installing"

# Create directory structure
echo -e "  Creating directories..."
mkdir -p "$INSTALL_DIR/config"
mkdir -p "$INSTALL_DIR/logs"

# Copy binaries from the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/$PLATFORM"

if [ ! -d "$PLATFORM_DIR" ]; then
    # Try current directory
    PLATFORM_DIR="$SCRIPT_DIR"
fi

if [ -f "$PLATFORM_DIR/supervisor" ] && [ -f "$PLATFORM_DIR/worker" ]; then
    echo -e "  Copying binaries from ${PLATFORM_DIR}..."
    cp "$PLATFORM_DIR/supervisor" "$INSTALL_DIR/supervisor"
    cp "$PLATFORM_DIR/worker" "$INSTALL_DIR/worker"
    chmod +x "$INSTALL_DIR/supervisor"
    chmod +x "$INSTALL_DIR/worker"
elif [ -f "$SCRIPT_DIR/supervisor" ] && [ -f "$SCRIPT_DIR/worker" ]; then
    echo -e "  Copying binaries..."
    cp "$SCRIPT_DIR/supervisor" "$INSTALL_DIR/supervisor"
    cp "$SCRIPT_DIR/worker" "$INSTALL_DIR/worker"
    chmod +x "$INSTALL_DIR/supervisor"
    chmod +x "$INSTALL_DIR/worker"
else
    echo -e "  ${YELLOW}Warning: Binaries not found in script directory.${NC}"
    echo -e "  ${YELLOW}Please manually copy supervisor and worker to: $INSTALL_DIR${NC}"
fi

# Generate config file
echo -e "  Generating configuration file..."
cat > "$INSTALL_DIR/config/default.toml" << EOF
[supervisor]
check_interval_secs = ${CHECK_INTERVAL}

[[workers]]
name = "${WORKER_NAME}"
port = ${SERVICE_PORT}
auto_restart = ${AUTO_RESTART}
EOF

# Generate startup script
echo -e "  Generating startup script..."
cat > "$INSTALL_DIR/start.sh" << 'STARTUP_HEADER'
#!/bin/bash
# Remote Control MCP - Startup Script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

STARTUP_HEADER

cat >> "$INSTALL_DIR/start.sh" << EOF

case "\${1:-start}" in
    start)
        echo "Starting Remote Control MCP..."
        echo "  Config: \$SCRIPT_DIR/config/default.toml"
        echo "  Port: ${SERVICE_PORT}"
        nohup ./supervisor > logs/supervisor.log 2>&1 &
        echo \$! > logs/supervisor.pid
        echo "Started (PID: \$!)"
        echo "Log: \$SCRIPT_DIR/logs/supervisor.log"
        ;;
    stop)
        if [ -f logs/supervisor.pid ]; then
            PID=\$(cat logs/supervisor.pid)
            echo "Stopping Remote Control MCP (PID: \$PID)..."
            kill \$PID 2>/dev/null
            rm -f logs/supervisor.pid
            echo "Stopped."
        else
            echo "No PID file found. Service may not be running."
        fi
        ;;
    restart)
        \$0 stop
        sleep 2
        \$0 start
        ;;
    status)
        if [ -f logs/supervisor.pid ]; then
            PID=\$(cat logs/supervisor.pid)
            if kill -0 \$PID 2>/dev/null; then
                echo "Running (PID: \$PID)"
            else
                echo "Not running (stale PID file)"
                rm -f logs/supervisor.pid
            fi
        else
            echo "Not running"
        fi
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
chmod +x "$INSTALL_DIR/start.sh"

# Generate stop script (convenience)
cat > "$INSTALL_DIR/stop.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/start.sh" stop
EOF
chmod +x "$INSTALL_DIR/stop.sh"

# Done
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Installation Complete!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Install location: ${CYAN}$INSTALL_DIR${NC}"
echo -e "  Configuration:    ${CYAN}$INSTALL_DIR/config/default.toml${NC}"
echo ""
echo -e "  ${GREEN}Start service:${NC}   $INSTALL_DIR/start.sh start"
echo -e "  ${GREEN}Stop service:${NC}    $INSTALL_DIR/start.sh stop"
echo -e "  ${GREEN}Check status:${NC}    $INSTALL_DIR/start.sh status"
echo -e "  ${GREEN}View logs:${NC}       tail -f $INSTALL_DIR/logs/supervisor.log"
echo ""
