#!/usr/bin/env bash
# ============================================================
#  L3MON Universal Installer
#  Supports: Termux (Android), macOS, Linux (apt/dnf/pacman), Windows (WSL/Git Bash)
#  Author: Abhishek Babu <thebizarreabhishek@users.noreply.github.com>
# ============================================================

set -e

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[✔]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[✘]${RESET} $1"; exit 1; }

# ── Banner ───────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "  ██╗     ██████╗ ███╗   ███╗ ██████╗ ███╗   ██╗"
echo "  ██║     ╚════██╗████╗ ████║██╔═══██╗████╗  ██║"
echo "  ██║      █████╔╝██╔████╔██║██║   ██║██╔██╗ ██║"
echo "  ██║      ╚═══██╗██║╚██╔╝██║██║   ██║██║╚██╗██║"
echo "  ███████╗██████╔╝██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
echo "  ╚══════╝╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
echo -e "${RESET}${BOLD}         Universal Installer${RESET}"
echo ""

# ── Platform Detection ───────────────────────────────────────
detect_platform() {
    if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
        PLATFORM="termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Detect Linux distro
        if command -v apt-get &>/dev/null; then
            PLATFORM="linux-apt"
        elif command -v dnf &>/dev/null; then
            PLATFORM="linux-dnf"
        elif command -v pacman &>/dev/null; then
            PLATFORM="linux-pacman"
        else
            PLATFORM="linux-unknown"
        fi
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        PLATFORM="windows-bash"
    else
        PLATFORM="unknown"
    fi

    echo -e "${BOLD}Platform detected:${RESET} ${GREEN}$PLATFORM${RESET}"
    echo ""
}

# ── Install Node.js ──────────────────────────────────────────
install_node() {
    if command -v node &>/dev/null; then
        NODE_VER=$(node --version)
        success "Node.js already installed: $NODE_VER"
        return
    fi
    info "Installing Node.js..."
    case $PLATFORM in
        termux)
            pkg install -y nodejs ;;
        macos)
            if ! command -v brew &>/dev/null; then
                info "Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install node ;;
        linux-apt|wsl)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs ;;
        linux-dnf)
            sudo dnf install -y nodejs npm ;;
        linux-pacman)
            sudo pacman -Sy --noconfirm nodejs npm ;;
        windows-bash)
            error "Please install Node.js manually from https://nodejs.org then rerun this script." ;;
        *)
            error "Cannot auto-install Node.js on this platform. Install it manually from https://nodejs.org" ;;
    esac
    success "Node.js installed: $(node --version)"
}

# ── Install Java (JDK) ───────────────────────────────────────
install_java() {
    if java -version &>/dev/null 2>&1; then
        JAVA_VER=$(java -version 2>&1 | head -1)
        success "Java already installed: $JAVA_VER"
        return
    fi
    info "Installing Java..."
    case $PLATFORM in
        termux)
            pkg install -y openjdk-17 ;;
        macos)
            brew install openjdk
            # Link for system java wrappers
            sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" \
                /Library/Java/JavaVirtualMachines/openjdk.jdk 2>/dev/null || true ;;
        linux-apt|wsl)
            sudo apt-get install -y default-jdk ;;
        linux-dnf)
            sudo dnf install -y java-latest-openjdk ;;
        linux-pacman)
            sudo pacman -Sy --noconfirm jdk-openjdk ;;
        *)
            error "Cannot auto-install Java on this platform. Install any JDK from https://adoptium.net" ;;
    esac
    success "Java installed: $(java -version 2>&1 | head -1)"
}

# ── Install apktool (Termux only) ────────────────────────────
install_apktool_termux() {
    if [ "$PLATFORM" != "termux" ]; then return; fi

    if command -v apktool &>/dev/null; then
        success "apktool already installed: $(apktool --version 2>/dev/null || echo 'ok')"
        return
    fi

    info "Installing apktool for Termux..."

    # Install zip (needed for smali+zip APK rebuild path)
    pkg install -y zip 2>/dev/null || true

    # Method 1: Try tur-repo (Termux User Repository)
    if pkg install -y tur-repo 2>/dev/null && pkg install -y apktool 2>/dev/null; then
        success "apktool installed via tur-repo."
        return
    fi

    # Method 2: Manually download latest apktool jar + create wrapper
    warn "tur-repo not available. Downloading apktool manually..."
    APKTOOL_VER="2.9.3"
    APKTOOL_JAR="$PREFIX/lib/apktool.jar"
    APKTOOL_BIN="$PREFIX/bin/apktool"

    curl -L --progress-bar \
        "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VER}/apktool_${APKTOOL_VER}.jar" \
        -o "$APKTOOL_JAR"

    # Create wrapper script
    cat > "$APKTOOL_BIN" << APKTOOL_WRAPPER
#!/bin/bash
exec java -jar "$APKTOOL_JAR" "\$@"
APKTOOL_WRAPPER
    chmod +x "$APKTOOL_BIN"
    success "apktool $APKTOOL_VER installed manually."
}

# ── Install Git ──────────────────────────────────────────────
install_git() {
    if command -v git &>/dev/null; then
        success "Git already installed: $(git --version)"
        return
    fi
    info "Installing Git..."
    case $PLATFORM in
        termux)     pkg install -y git ;;
        macos)      brew install git ;;
        linux-apt|wsl)   sudo apt-get install -y git ;;
        linux-dnf)  sudo dnf install -y git ;;
        linux-pacman) sudo pacman -Sy --noconfirm git ;;
        *) error "Please install git manually from https://git-scm.com" ;;
    esac
    success "Git installed."
}

# ── Setup Keystore ───────────────────────────────────────────
setup_keystore() {
    KEYSTORE_PATH="$(dirname "$0")/.files/app/factory/l3mon.jks"
    if [ -f "$KEYSTORE_PATH" ]; then
        success "Keystore already exists."
        return
    fi
    info "Generating signing keystore..."
    keytool -genkey -v \
        -keystore "$KEYSTORE_PATH" \
        -alias testkey \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass l3mon123 \
        -keypass l3mon123 \
        -dname "CN=L3MON, OU=L3MON, O=L3MON, L=Unknown, S=Unknown, C=US" \
        -noprompt 2>/dev/null
    success "Keystore generated."
}

# ── npm install ──────────────────────────────────────────────
install_npm_deps() {
    FILES_DIR="$(dirname "$0")/.files"
    info "Installing Node.js dependencies..."
    cd "$FILES_DIR"
    npm install --prefer-offline 2>/dev/null || npm install
    success "Dependencies installed."
    cd - > /dev/null
}

# ── Create start script ──────────────────────────────────────
create_start_script() {
    START_SCRIPT="$(dirname "$0")/start.sh"
    cat > "$START_SCRIPT" << 'STARTSCRIPT'
#!/usr/bin/env bash
# L3MON Start Script
cd "$(dirname "$0")/.files"

# Find node binary
if command -v node &>/dev/null; then
    NODE_BIN="node"
elif [ -f "/opt/homebrew/bin/node" ]; then
    NODE_BIN="/opt/homebrew/bin/node"
else
    echo "Error: node not found. Run install.sh first."
    exit 1
fi

echo ""
echo "  Starting L3MON..."
echo "  Web Panel   → http://localhost:22533"
echo "  Socket Port → 22222"
echo "  Press Ctrl+C to stop"
echo ""
$NODE_BIN index.js
STARTSCRIPT
    chmod +x "$START_SCRIPT"
    success "Start script created: ./start.sh"
}

# ── Main ─────────────────────────────────────────────────────
main() {
    detect_platform

    info "Step 1/6 — Checking Git..."
    install_git

    info "Step 2/6 — Checking Node.js..."
    install_node

    info "Step 3/6 — Checking Java..."
    install_java

    info "Step 4/6 — Installing apktool (Termux)..."
    install_apktool_termux

    info "Step 5/6 — Installing npm dependencies..."
    install_npm_deps

    info "Step 6/6 — Setting up keystore & start script..."
    setup_keystore
    create_start_script

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║         L3MON Setup Complete! ✔          ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}To start the server:${RESET}"
    echo -e "  ${CYAN}./start.sh${RESET}"
    echo ""
    echo -e "  ${BOLD}Web Panel:${RESET}   ${CYAN}http://localhost:22533${RESET}"
    echo -e "  ${BOLD}Socket Port:${RESET} ${CYAN}22222${RESET}"
    echo ""
}

main "$@"
