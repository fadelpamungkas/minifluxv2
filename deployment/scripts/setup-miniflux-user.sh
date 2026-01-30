#!/bin/bash
# Setup Miniflux System User
# Creates a dedicated system user for running Miniflux
#
# Usage: sudo ./setup-miniflux-user.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

USER_NAME="miniflux"
GROUP_NAME="miniflux"

echo -e "${GREEN}=== Setting up Miniflux System User ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Check if user already exists
if id "$USER_NAME" &>/dev/null; then
    echo -e "${YELLOW}User $USER_NAME already exists${NC}"
    echo -e "${YELLOW}Skipping user creation...${NC}"
else
    # Create group
    if getent group "$GROUP_NAME" > /dev/null 2>&1; then
        echo -e "${YELLOW}Group $GROUP_NAME already exists${NC}"
    else
        echo -e "${GREEN}Creating group $GROUP_NAME...${NC}"
        groupadd -r "$GROUP_NAME"
    fi
    
    # Create user
    echo -e "${GREEN}Creating user $USER_NAME...${NC}"
    useradd -r -g "$GROUP_NAME" -d /dev/null -s /bin/false -c "Miniflux Daemon" "$USER_NAME"
    
    echo -e "${GREEN}User $USER_NAME created successfully${NC}"
fi

# Create runtime directory
RUNTIME_DIR="/run/miniflux"
if [ ! -d "$RUNTIME_DIR" ]; then
    echo -e "${GREEN}Creating runtime directory $RUNTIME_DIR...${NC}"
    mkdir -p "$RUNTIME_DIR"
    chown "$USER_NAME:$GROUP_NAME" "$RUNTIME_DIR"
    chmod 750 "$RUNTIME_DIR"
    echo -e "${GREEN}Runtime directory created${NC}"
else
    echo -e "${YELLOW}Runtime directory already exists${NC}"
    chown "$USER_NAME:$GROUP_NAME" "$RUNTIME_DIR"
    chmod 750 "$RUNTIME_DIR"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}User Information:${NC}"
echo "  Username: $USER_NAME"
echo "  Group: $GROUP_NAME"
echo "  Home: /dev/null (no login shell)"
echo "  Runtime Directory: $RUNTIME_DIR"
echo ""
