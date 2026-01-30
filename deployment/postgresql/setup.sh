#!/bin/bash
# PostgreSQL Setup Script for Miniflux
# This script installs and configures PostgreSQL for Miniflux deployment
#
# Usage: sudo ./setup.sh
#
# Requirements:
#   - Ubuntu/Debian or CentOS/RHEL system
#   - Root or sudo access
#   - Internet connection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables (modify as needed)
DB_NAME="miniflux"
DB_USER="miniflux"
DB_PASSWORD="secret_pass"  # CHANGE THIS PASSWORD!

echo -e "${GREEN}=== PostgreSQL Setup for Miniflux ===${NC}"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS. This script supports Ubuntu/Debian and CentOS/RHEL.${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected OS: $OS $VER${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Install PostgreSQL
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    echo -e "${GREEN}Installing PostgreSQL 15...${NC}"
    apt-get update
    apt-get install -y postgresql-15 postgresql-contrib-15
    
    PG_VERSION="15"
    PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    PG_DATA="/var/lib/postgresql/$PG_VERSION/main"
    
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    echo -e "${GREEN}Installing PostgreSQL 15...${NC}"
    
    # Install PostgreSQL repository
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf install -y postgresql15-server postgresql15
    
    # Initialize database
    /usr/pgsql-15/bin/postgresql-15-setup initdb
    
    PG_VERSION="15"
    PG_CONF="/var/lib/pgsql/$PG_VERSION/data/postgresql.conf"
    PG_HBA="/var/lib/pgsql/$PG_VERSION/data/pg_hba.conf"
    PG_DATA="/var/lib/pgsql/$PG_VERSION/data"
    
    # Start and enable PostgreSQL
    systemctl enable postgresql-15
    systemctl start postgresql-15
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

echo -e "${GREEN}PostgreSQL installed successfully${NC}"
echo ""

# Start PostgreSQL service
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    systemctl enable postgresql
    systemctl start postgresql
fi

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to start...${NC}"
sleep 3

# Create database and user
echo -e "${GREEN}Creating database and user...${NC}"

sudo -u postgres psql <<EOF
-- Create user
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Create database
CREATE DATABASE $DB_NAME OWNER $DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Connect to database and grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;

\q
EOF

echo -e "${GREEN}Database and user created successfully${NC}"
echo ""

# Configure PostgreSQL for local connections
echo -e "${GREEN}Configuring PostgreSQL authentication...${NC}"

# Add local connection configuration to pg_hba.conf if not present
if ! grep -q "local.*$DB_NAME.*$DB_USER" "$PG_HBA"; then
    echo "local   $DB_NAME             $DB_USER                                 md5" >> "$PG_HBA"
fi

if ! grep -q "host.*$DB_NAME.*$DB_USER.*127.0.0.1" "$PG_HBA"; then
    echo "host    $DB_NAME             $DB_USER             127.0.0.1/32            md5" >> "$PG_HBA"
fi

# Reload PostgreSQL configuration
systemctl reload postgresql

echo -e "${GREEN}PostgreSQL authentication configured${NC}"
echo ""

# Apply resource-optimized settings
echo -e "${GREEN}Applying resource-optimized settings...${NC}"

# Check if settings file exists (from deployment/postgresql/postgresql.conf)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_SNIPPET="$SCRIPT_DIR/postgresql.conf"

if [ -f "$CONF_SNIPPET" ]; then
    echo -e "${YELLOW}Note: Please manually review and add settings from:${NC}"
    echo -e "${YELLOW}  $CONF_SNIPPET${NC}"
    echo -e "${YELLOW}to your PostgreSQL config: $PG_CONF${NC}"
    echo ""
    echo -e "${YELLOW}Key settings to add:${NC}"
    echo "  shared_buffers = 32MB"
    echo "  work_mem = 2MB"
    echo "  maintenance_work_mem = 16MB"
    echo "  max_connections = 20"
    echo ""
    echo -e "${YELLOW}After adding settings, restart PostgreSQL:${NC}"
    echo "  sudo systemctl restart postgresql"
else
    # Apply settings directly if snippet not found
    echo -e "${YELLOW}Applying basic resource settings...${NC}"
    
    # Backup original config
    cp "$PG_CONF" "$PG_CONF.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add settings if not present
    for setting in "shared_buffers = 32MB" "work_mem = 2MB" "maintenance_work_mem = 16MB" "max_connections = 20"; do
        key=$(echo "$setting" | cut -d'=' -f1 | xargs)
        if ! grep -q "^$key" "$PG_CONF"; then
            echo "$setting" >> "$PG_CONF"
        fi
    done
    
    # Restart PostgreSQL to apply settings
    systemctl restart postgresql
    echo -e "${GREEN}Resource settings applied${NC}"
fi

echo ""
echo -e "${GREEN}=== PostgreSQL Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Database Information:${NC}"
echo "  Database Name: $DB_NAME"
echo "  Database User: $DB_USER"
echo "  Database Password: $DB_PASSWORD"
echo "  Connection String: postgres://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME?sslmode=disable"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  1. Change the database password in production!"
echo "  2. Update DATABASE_URL in /etc/miniflux.conf with the connection string above"
echo "  3. Test connection: psql -U $DB_USER -d $DB_NAME -h localhost"
echo ""
