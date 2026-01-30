#!/bin/bash
# Database Backup Script for Miniflux
# Creates a timestamped backup of the Miniflux PostgreSQL database
#
# Usage: 
#   ./backup-db.sh                    # Backup to default location
#   ./backup-db.sh /path/to/backup    # Backup to custom location
#
# Requirements:
#   - PostgreSQL client tools (pg_dump)
#   - Access to PostgreSQL database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration (modify as needed)
DB_NAME="${DB_NAME:-miniflux}"
DB_USER="${DB_USER:-miniflux}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Backup directory
if [ -n "$1" ]; then
    BACKUP_DIR="$1"
else
    BACKUP_DIR="${HOME}/miniflux-backups"
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/miniflux_backup_${TIMESTAMP}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

echo -e "${GREEN}=== Miniflux Database Backup ===${NC}"
echo ""
echo -e "${YELLOW}Backup Information:${NC}"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Backup File: $BACKUP_FILE"
echo ""

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump not found. Please install PostgreSQL client tools.${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  CentOS/RHEL: sudo yum install postgresql"
    exit 1
fi

# Prompt for password if needed
export PGPASSWORD="${DB_PASSWORD:-}"

# Perform backup
echo -e "${GREEN}Creating backup...${NC}"
if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -F p > "$BACKUP_FILE"; then
    echo -e "${GREEN}Backup created successfully${NC}"
    
    # Compress backup
    echo -e "${GREEN}Compressing backup...${NC}"
    gzip -f "$BACKUP_FILE"
    
    BACKUP_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
    echo -e "${GREEN}Backup compressed: $COMPRESSED_FILE (${BACKUP_SIZE})${NC}"
    
    # Clean up old backups (keep last 7 days)
    echo -e "${YELLOW}Cleaning up old backups (keeping last 7 days)...${NC}"
    find "$BACKUP_DIR" -name "miniflux_backup_*.sql.gz" -type f -mtime +7 -delete
    
    echo ""
    echo -e "${GREEN}=== Backup Complete ===${NC}"
    echo ""
    echo -e "${YELLOW}Backup Location:${NC}"
    echo "  $COMPRESSED_FILE"
    echo ""
    echo -e "${YELLOW}To restore this backup:${NC}"
    echo "  gunzip < $COMPRESSED_FILE | psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
    echo ""
else
    echo -e "${RED}Backup failed!${NC}"
    exit 1
fi

# Unset password
unset PGPASSWORD
