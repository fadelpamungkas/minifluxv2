#!/bin/bash
# Miniflux Installation Script
# Automated installation script for Miniflux binary deployment
#
# Usage: sudo ./install.sh
#
# Requirements:
#   - Ubuntu/Debian or CentOS/RHEL system
#   - Root or sudo access
#   - Internet connection
#   - At least 1GB RAM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
MINIFLUX_VERSION="latest"  # Use "latest" or specific version like "2.1.0"
MINIFLUX_BINARY="/usr/local/bin/miniflux"
MINIFLUX_CONF="/etc/miniflux.conf"
MINIFLUX_SERVICE="/etc/systemd/system/miniflux.service"
NGINX_SITE="/etc/nginx/sites-available/miniflux"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Miniflux Binary Deployment Installation             ║"
echo "║         Optimized for 1GB RAM Server                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root or with sudo${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Error: Cannot detect OS. This script supports Ubuntu/Debian and CentOS/RHEL.${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $OS $VER${NC}"
echo ""

# Check available memory (basic check)
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 900 ]; then
    echo -e "${YELLOW}Warning: System has less than 1GB RAM (${TOTAL_MEM}MB detected)${NC}"
    echo -e "${YELLOW}This deployment is optimized for 1GB RAM, but may be tight.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================
# Step 1: Install Required Packages
# ============================================
echo -e "${BLUE}=== Step 1: Installing Required Packages ===${NC}"
echo ""

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update
    apt-get install -y curl wget nginx certbot python3-certbot-nginx postgresql-client
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    dnf install -y curl wget nginx certbot python3-certbot-nginx postgresql
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

echo -e "${GREEN}Packages installed successfully${NC}"
echo ""

# ============================================
# Step 2: Setup PostgreSQL
# ============================================
echo -e "${BLUE}=== Step 2: Setting up PostgreSQL ===${NC}"
echo ""

if [ -f "$DEPLOYMENT_DIR/postgresql/setup.sh" ]; then
    echo -e "${YELLOW}Running PostgreSQL setup script...${NC}"
    bash "$DEPLOYMENT_DIR/postgresql/setup.sh"
else
    echo -e "${YELLOW}PostgreSQL setup script not found. Skipping...${NC}"
    echo -e "${YELLOW}Please run: sudo $DEPLOYMENT_DIR/postgresql/setup.sh${NC}"
fi

echo ""

# ============================================
# Step 3: Download Miniflux Binary
# ============================================
echo -e "${BLUE}=== Step 3: Downloading Miniflux Binary ===${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        BINARY_ARCH="amd64"
        ;;
    aarch64|arm64)
        BINARY_ARCH="arm64"
        ;;
    armv7l)
        BINARY_ARCH="armv7"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Architecture detected: $ARCH ($BINARY_ARCH)${NC}"

# Get latest version if needed
if [ "$MINIFLUX_VERSION" = "latest" ]; then
    echo -e "${YELLOW}Fetching latest Miniflux version...${NC}"
    MINIFLUX_VERSION=$(curl -s https://api.github.com/repos/miniflux/v2/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo -e "${GREEN}Latest version: $MINIFLUX_VERSION${NC}"
fi

# Download binary
BINARY_URL="https://github.com/miniflux/v2/releases/download/${MINIFLUX_VERSION}/miniflux-linux-${BINARY_ARCH}"
echo -e "${YELLOW}Downloading Miniflux ${MINIFLUX_VERSION} from GitHub...${NC}"

if curl -L -f -o /tmp/miniflux "$BINARY_URL"; then
    chmod +x /tmp/miniflux
    mv /tmp/miniflux "$MINIFLUX_BINARY"
    echo -e "${GREEN}Miniflux binary installed to $MINIFLUX_BINARY${NC}"
else
    echo -e "${RED}Failed to download Miniflux binary${NC}"
    exit 1
fi

echo ""

# ============================================
# Step 4: Setup Miniflux User
# ============================================
echo -e "${BLUE}=== Step 4: Setting up Miniflux User ===${NC}"
echo ""

if [ -f "$DEPLOYMENT_DIR/scripts/setup-miniflux-user.sh" ]; then
    bash "$DEPLOYMENT_DIR/scripts/setup-miniflux-user.sh"
else
    echo -e "${YELLOW}User setup script not found. Creating user manually...${NC}"
    if ! id miniflux &>/dev/null; then
        groupadd -r miniflux
        useradd -r -g miniflux -d /dev/null -s /bin/false -c "Miniflux Daemon" miniflux
    fi
fi

chown miniflux:miniflux "$MINIFLUX_BINARY"
echo ""

# ============================================
# Step 5: Configure Miniflux
# ============================================
echo -e "${BLUE}=== Step 5: Configuring Miniflux ===${NC}"
echo ""

if [ -f "$DEPLOYMENT_DIR/miniflux/miniflux.conf" ]; then
    cp "$DEPLOYMENT_DIR/miniflux/miniflux.conf" "$MINIFLUX_CONF"
    chmod 600 "$MINIFLUX_CONF"
    echo -e "${GREEN}Miniflux configuration copied to $MINIFLUX_CONF${NC}"
    echo -e "${YELLOW}IMPORTANT: Please review and update $MINIFLUX_CONF${NC}"
    echo -e "${YELLOW}  - Update BASE_URL with your domain${NC}"
    echo -e "${YELLOW}  - Update DATABASE_URL with correct credentials${NC}"
    echo -e "${YELLOW}  - Update any other settings as needed${NC}"
else
    echo -e "${RED}Miniflux configuration file not found!${NC}"
    exit 1
fi

echo ""

# ============================================
# Step 6: Setup Systemd Service
# ============================================
echo -e "${BLUE}=== Step 6: Setting up Systemd Service ===${NC}"
echo ""

if [ -f "$DEPLOYMENT_DIR/miniflux/miniflux.service" ]; then
    cp "$DEPLOYMENT_DIR/miniflux/miniflux.service" "$MINIFLUX_SERVICE"
    systemctl daemon-reload
    systemctl enable miniflux
    echo -e "${GREEN}Systemd service configured${NC}"
else
    echo -e "${RED}Systemd service file not found!${NC}"
    exit 1
fi

echo ""

# ============================================
# Step 7: Configure Nginx
# ============================================
echo -e "${BLUE}=== Step 7: Configuring Nginx ===${NC}"
echo ""

if [ -f "$DEPLOYMENT_DIR/nginx/miniflux.conf" ]; then
    cp "$DEPLOYMENT_DIR/nginx/miniflux.conf" "$NGINX_SITE"
    
    # Create symlink if it doesn't exist
    if [ ! -L /etc/nginx/sites-enabled/miniflux ]; then
        ln -s "$NGINX_SITE" /etc/nginx/sites-enabled/
    fi
    
    # Test Nginx configuration
    if nginx -t; then
        echo -e "${GREEN}Nginx configuration is valid${NC}"
        systemctl reload nginx
    else
        echo -e "${RED}Nginx configuration test failed!${NC}"
        echo -e "${YELLOW}Please fix the configuration before proceeding${NC}"
    fi
else
    echo -e "${RED}Nginx configuration file not found!${NC}"
    exit 1
fi

echo ""

# ============================================
# Installation Summary
# ============================================
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Installation Complete                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Miniflux has been installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${BLUE}Update Configuration:${NC}"
echo "   sudo nano $MINIFLUX_CONF"
echo "   - Update BASE_URL with your domain"
echo "   - Update DATABASE_URL with correct credentials"
echo ""
echo "2. ${BLUE}Setup SSL Certificate:${NC}"
echo "   sudo certbot --nginx -d YOUR_DOMAIN"
echo ""
echo "3. ${BLUE}Start Miniflux Service:${NC}"
echo "   sudo systemctl start miniflux"
echo "   sudo systemctl status miniflux"
echo ""
echo "4. ${BLUE}Check Logs:${NC}"
echo "   sudo journalctl -u miniflux -f"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "   sudo systemctl start miniflux      # Start service"
echo "   sudo systemctl stop miniflux       # Stop service"
echo "   sudo systemctl restart miniflux    # Restart service"
echo "   sudo systemctl status miniflux     # Check status"
echo "   sudo journalctl -u miniflux -f     # View logs"
echo ""
echo -e "${YELLOW}Access Miniflux:${NC}"
echo "   https://YOUR_DOMAIN/miniflux"
echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
