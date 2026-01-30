# Miniflux Binary Deployment Guide

Complete step-by-step guide for deploying Miniflux as a binary on a resource-constrained server (1GB RAM) with Nginx reverse proxy and PostgreSQL.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Installation](#manual-installation)
- [Configuration](#configuration)
- [SSL Setup](#ssl-setup)
- [Service Management](#service-management)
- [Troubleshooting](#troubleshooting)
- [Migration from Docker](#migration-from-docker)
- [Backup and Restore](#backup-and-restore)

## Overview

This deployment package provides:

- **Miniflux binary** - Runs directly on the system (no Docker overhead)
- **Nginx reverse proxy** - Handles SSL termination and path prefix routing (`/miniflux`)
- **PostgreSQL** - System package installation (no Docker)
- **Resource optimization** - Configured for 1GB RAM servers
- **Systemd service** - Automatic startup and management

### Resource Allocation (1GB RAM)

- System + Nginx: ~50MB
- PostgreSQL: ~150-200MB
- Miniflux binary: ~30-50MB
- **Total used: ~230-300MB**
- **Available buffer: ~700-770MB**

### Why Binary Over Docker?

- **Lower memory usage**: No container runtime overhead (~150-300MB saved)
- **Better performance**: Direct system calls, no virtualization layer
- **Simpler management**: Standard systemd service, easier debugging
- **Maximum efficiency**: Critical for 1GB RAM servers

## Prerequisites

### Server Requirements

- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / RHEL 8+
- **RAM**: Minimum 1GB (optimized for 1GB)
- **Storage**: Minimum 5GB free space
- **CPU**: 1 vCPU minimum
- **Network**: Internet connection for installation

### Access Requirements

- Root or sudo access
- SSH access to the server
- Domain name pointing to server IP (for SSL)

### Before You Start

1. **Backup existing data** (if migrating from Docker)
2. **Update system packages**: `sudo apt update && sudo apt upgrade` (Ubuntu/Debian)
3. **Ensure domain DNS** is pointing to your server IP

## Server Access Methods

### Method 1: Web Terminal (Dalang.io)

If you have terminal access via Dalang.io website:

1. **Log in to Dalang.io** dashboard
2. **Open Web Terminal** for your server
3. **Upload files** using the web interface or use `scp`/`rsync` from your local machine

**To upload files via web terminal:**
```bash
# In web terminal, create directory
mkdir -p /tmp/deployment

# Then use web interface file upload, or use curl/wget to download from your machine
```

**To download files from your local machine to server:**
```bash
# From your local machine, if you have SSH access:
scp -r deployment/ root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io:/tmp/

# Or using the local IP (if accessible):
scp -r deployment/ root@10.70.0.62:/tmp/
```

### Method 2: SSH Access

If you have SSH credentials:

**Using Public Domain:**
```bash
ssh root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io
# or
ssh root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io -p 22
```

**Using Local IP (if accessible from your network):**
```bash
ssh root@10.70.0.62
# or
ssh root@10.70.0.62 -p 22
```

**Copy files via SCP:**
```bash
# Using public domain
scp -r deployment/ root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io:/tmp/

# Using local IP
scp -r deployment/ root@10.70.0.62:/tmp/
```

**Note:** 
- Replace `root` with your actual username if different
- You may need to use a different port (check Dalang.io documentation)
- If SSH is not enabled, use the web terminal method

### Method 3: Direct File Transfer

**Option A: Using Git (if server has git):**
```bash
# On server (via web terminal or SSH)
cd /tmp
git clone <your-repo-url>
cd minifluxv2
```

**Option B: Using curl/wget to download from URL:**
```bash
# Upload deployment folder to a temporary location (GitHub, file host, etc.)
# Then on server:
cd /tmp
wget https://your-file-host.com/deployment.tar.gz
tar -xzf deployment.tar.gz
```

## Quick Start

### For Dalang.io Users (Web Terminal)

If you're using Dalang.io with web terminal access, see **[DALANG_QUICK_START.md](DALANG_QUICK_START.md)** for simplified instructions.

### Option 1: Automated Installation

```bash
# 1. Copy deployment directory to server
# Using public domain:
scp -r deployment/ root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io:/tmp/
# Or using local IP (if accessible):
scp -r deployment/ root@10.70.0.62:/tmp/

# 2. Access server (SSH or web terminal)
ssh root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io
# Or use Dalang.io web terminal

# 3. Run installation script
cd /tmp/deployment
sudo ./scripts/install.sh

# 4. Update configuration
sudo nano /etc/miniflux.conf
# - BASE_URL is already set to: https://38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io/miniflux
# - Update DATABASE_URL with correct credentials

# 5. Setup SSL
sudo certbot --nginx -d 38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io

# 6. Start Miniflux
sudo systemctl start miniflux
sudo systemctl status miniflux
```

### Option 2: Manual Installation

Follow the detailed steps in [Manual Installation](#manual-installation) section below.

## Manual Installation

### Step 1: Copy Files to Server

```bash
# From your local machine
scp -r deployment/ user@your-server:/tmp/deployment

# Or use rsync for better progress
rsync -avz deployment/ user@your-server:/tmp/deployment/
```

### Step 2: Install Required Packages

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y curl wget nginx certbot python3-certbot-nginx postgresql-15 postgresql-contrib-15
```

**CentOS/RHEL:**
```bash
sudo dnf install -y curl wget nginx certbot python3-certbot-nginx postgresql15-server postgresql15
```

### Step 3: Setup PostgreSQL

```bash
cd /tmp/deployment
sudo ./postgresql/setup.sh
```

This script will:
- Install PostgreSQL 15
- Create `miniflux` database and user
- Apply resource-optimized settings
- Configure authentication

**Important**: Update the password in `postgresql/setup.sh` before running, or change it after installation.

**Manual PostgreSQL Setup** (if script fails):

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql <<EOF
CREATE USER miniflux WITH PASSWORD 'your_secure_password';
CREATE DATABASE miniflux OWNER miniflux;
GRANT ALL PRIVILEGES ON DATABASE miniflux TO miniflux;
\c miniflux
GRANT ALL ON SCHEMA public TO miniflux;
\q
EOF

# Configure authentication (edit pg_hba.conf)
sudo nano /etc/postgresql/15/main/pg_hba.conf
# Add line: local   miniflux             miniflux                                 md5
# Add line: host    miniflux             miniflux             127.0.0.1/32            md5

sudo systemctl reload postgresql
```

### Step 4: Download Miniflux Binary

```bash
# Detect architecture
ARCH=$(uname -m)

# Download latest version
# For amd64:
sudo wget -O /usr/local/bin/miniflux \
  https://github.com/miniflux/v2/releases/latest/download/miniflux-linux-amd64

# For arm64:
# sudo wget -O /usr/local/bin/miniflux \
#   https://github.com/miniflux/v2/releases/latest/download/miniflux-linux-arm64

# Make executable
sudo chmod +x /usr/local/bin/miniflux
```

### Step 5: Create Miniflux User

```bash
cd /tmp/deployment
sudo ./scripts/setup-miniflux-user.sh
```

Or manually:
```bash
sudo groupadd -r miniflux
sudo useradd -r -g miniflux -d /dev/null -s /bin/false -c "Miniflux Daemon" miniflux
sudo mkdir -p /run/miniflux
sudo chown miniflux:miniflux /run/miniflux
sudo chown miniflux:miniflux /usr/local/bin/miniflux
```

### Step 6: Configure Miniflux

```bash
# Copy configuration file
sudo cp /tmp/deployment/miniflux/miniflux.conf /etc/miniflux.conf
sudo chmod 600 /etc/miniflux.conf

# Edit configuration
sudo nano /etc/miniflux.conf
```

**Required changes:**
- `BASE_URL`: Update with your domain and path prefix: `https://your-domain.com/miniflux`
- `DATABASE_URL`: Update with PostgreSQL credentials: `postgres://miniflux:password@localhost/miniflux?sslmode=disable`

**Example configuration:**
```bash
DATABASE_URL=postgres://miniflux:your_password@localhost/miniflux?sslmode=disable
RUN_MIGRATIONS=1
BASE_URL=https://38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io/miniflux
LISTEN_ADDR=127.0.0.1:8080
WORKER_POOL_SIZE=2
BATCH_SIZE=10
DATABASE_MAX_CONNS=5
DATABASE_MIN_CONNS=1
POLLING_FREQUENCY=120
```

### Step 7: Setup Systemd Service

```bash
# Copy service file
sudo cp /tmp/deployment/miniflux/miniflux.service /etc/systemd/system/miniflux.service

# Reload systemd
sudo systemctl daemon-reload

# Enable service (starts on boot)
sudo systemctl enable miniflux
```

### Step 8: Configure Nginx

```bash
# Copy Nginx configuration
sudo cp /tmp/deployment/nginx/miniflux.conf /etc/nginx/sites-available/miniflux

# Edit configuration to update domain name
sudo nano /etc/nginx/sites-available/miniflux
# Replace: 38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io
# With: your-domain.com

# Enable site
sudo ln -s /etc/nginx/sites-available/miniflux /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Step 9: Setup SSL Certificate

```bash
# Install certbot (if not already installed)
sudo apt install certbot python3-certbot-nginx  # Ubuntu/Debian
# or
sudo dnf install certbot python3-certbot-nginx   # CentOS/RHEL

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com

# Certbot will automatically:
# - Obtain certificate from Let's Encrypt
# - Update Nginx configuration with SSL settings
# - Setup automatic renewal
```

### Step 10: Start Miniflux

```bash
# Start Miniflux service
sudo systemctl start miniflux

# Check status
sudo systemctl status miniflux

# View logs
sudo journalctl -u miniflux -f
```

### Step 11: Verify Installation

1. **Check service status**: `sudo systemctl status miniflux`
2. **Check Nginx**: `sudo systemctl status nginx`
3. **Check PostgreSQL**: `sudo systemctl status postgresql`
4. **Access Miniflux**: Open `https://your-domain.com/miniflux` in browser
5. **Check logs**: `sudo journalctl -u miniflux -n 50`

## Configuration

### Miniflux Configuration (`/etc/miniflux.conf`)

Key settings:

- **BASE_URL**: Must include full path prefix (`/miniflux`) for reverse proxy
- **LISTEN_ADDR**: Set to `127.0.0.1:8080` (local only, behind reverse proxy)
- **DATABASE_URL**: PostgreSQL connection string
- **Resource settings**: Optimized for 1GB RAM (WORKER_POOL_SIZE=2, BATCH_SIZE=10)

See `miniflux/miniflux.conf` for all available options.

### Nginx Configuration (`/etc/nginx/sites-available/miniflux`)

Key settings:

- **Server name**: Your domain name
- **SSL certificates**: Auto-configured by certbot
- **Path prefix**: `/miniflux` routes to Miniflux backend
- **Proxy headers**: Properly configured for HTTPS detection

### PostgreSQL Configuration

Resource-optimized settings are applied via `postgresql/setup.sh`:

- `shared_buffers = 32MB`
- `work_mem = 2MB`
- `maintenance_work_mem = 16MB`
- `max_connections = 20`

See `postgresql/postgresql.conf` for all settings.

## SSL Setup

### Automatic SSL with Let's Encrypt

```bash
# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Test renewal
sudo certbot renew --dry-run

# Certificates auto-renew via systemd timer
```

### Manual SSL Certificate

If you have your own SSL certificate:

1. Copy certificate files:
   ```bash
   sudo cp your-cert.pem /etc/letsencrypt/live/your-domain.com/fullchain.pem
   sudo cp your-key.pem /etc/letsencrypt/live/your-domain.com/privkey.pem
   ```

2. Update Nginx configuration:
   ```bash
   sudo nano /etc/nginx/sites-available/miniflux
   # Update ssl_certificate and ssl_certificate_key paths
   ```

3. Reload Nginx:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## Service Management

### Miniflux Service

```bash
# Start
sudo systemctl start miniflux

# Stop
sudo systemctl stop miniflux

# Restart
sudo systemctl restart miniflux

# Status
sudo systemctl status miniflux

# Enable (start on boot)
sudo systemctl enable miniflux

# Disable (don't start on boot)
sudo systemctl disable miniflux

# View logs
sudo journalctl -u miniflux -f
sudo journalctl -u miniflux -n 100  # Last 100 lines
```

### Nginx Service

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx  # Reload config without downtime
sudo systemctl status nginx
sudo nginx -t  # Test configuration
```

### PostgreSQL Service

```bash
sudo systemctl start postgresql
sudo systemctl stop postgresql
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

## Troubleshooting

### Miniflux Won't Start

1. **Check service status**:
   ```bash
   sudo systemctl status miniflux
   ```

2. **Check logs**:
   ```bash
   sudo journalctl -u miniflux -n 50
   ```

3. **Check configuration**:
   ```bash
   sudo /usr/local/bin/miniflux -info  # If available
   ```

4. **Common issues**:
   - **Database connection error**: Check `DATABASE_URL` in `/etc/miniflux.conf`
   - **Permission error**: Check file permissions (`chown miniflux:miniflux /usr/local/bin/miniflux`)
   - **Port already in use**: Check if port 8080 is available (`sudo netstat -tulpn | grep 8080`)

### Nginx Errors

1. **Test configuration**:
   ```bash
   sudo nginx -t
   ```

2. **Check error logs**:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   sudo tail -f /var/log/nginx/miniflux-error.log
   ```

3. **Common issues**:
   - **502 Bad Gateway**: Miniflux not running or wrong proxy_pass URL
   - **404 Not Found**: Path prefix mismatch (`/miniflux` in BASE_URL and Nginx config)
   - **SSL errors**: Certificate paths incorrect or expired

### Database Connection Issues

1. **Test PostgreSQL connection**:
   ```bash
   psql -U miniflux -d miniflux -h localhost
   ```

2. **Check PostgreSQL status**:
   ```bash
   sudo systemctl status postgresql
   ```

3. **Check authentication**:
   ```bash
   sudo cat /etc/postgresql/15/main/pg_hba.conf
   ```

4. **Common issues**:
   - **Authentication failed**: Check password in `DATABASE_URL`
   - **Connection refused**: PostgreSQL not running or wrong port
   - **Database doesn't exist**: Run migrations or create database

### High Memory Usage

If you're running out of memory:

1. **Check memory usage**:
   ```bash
   free -h
   ps aux --sort=-%mem | head -10
   ```

2. **Reduce PostgreSQL memory**:
   - Edit `/etc/postgresql/15/main/postgresql.conf`
   - Reduce `shared_buffers` to 24MB
   - Reduce `work_mem` to 1MB

3. **Reduce Miniflux workers**:
   - Edit `/etc/miniflux.conf`
   - Set `WORKER_POOL_SIZE=1`

### Path Prefix Not Working

If accessing `/miniflux` returns 404:

1. **Check BASE_URL**: Must include `/miniflux` path prefix
2. **Check Nginx config**: Location block should be `/miniflux`
3. **Check Miniflux logs**: Look for routing errors
4. **Test directly**: `curl http://localhost:8080/` (should redirect to `/miniflux`)

## Migration from Docker

### Step 1: Backup Docker Database

```bash
# On your Docker server
docker exec postgres-db pg_dump -U miniflux miniflux > miniflux_backup.sql
```

### Step 2: Transfer Backup

```bash
# Copy backup to new server
scp miniflux_backup.sql user@new-server:/tmp/
```

### Step 3: Restore Database

```bash
# On new server
psql -U miniflux -d miniflux -h localhost < /tmp/miniflux_backup.sql
```

### Step 4: Update Configuration

Update `/etc/miniflux.conf` with your settings from Docker environment variables.

### Step 5: Run Migrations

```bash
# Miniflux will run migrations automatically if RUN_MIGRATIONS=1
# Or run manually:
sudo -u miniflux /usr/local/bin/miniflux -migrate
```

## Backup and Restore

### Backup Database

**Using provided script:**
```bash
cd /tmp/deployment
sudo ./scripts/backup-db.sh
```

**Manual backup:**
```bash
# Set password (or use .pgpass file)
export PGPASSWORD=your_password

# Create backup
pg_dump -U miniflux -d miniflux -h localhost > miniflux_backup_$(date +%Y%m%d).sql

# Compress
gzip miniflux_backup_$(date +%Y%m%d).sql
```

### Restore Database

```bash
# Decompress if needed
gunzip miniflux_backup_YYYYMMDD.sql.gz

# Restore
psql -U miniflux -d miniflux -h localhost < miniflux_backup_YYYYMMDD.sql
```

### Automated Backups

Add to crontab:
```bash
# Edit crontab
sudo crontab -e

# Add line (backup daily at 2 AM)
0 2 * * * /path/to/deployment/scripts/backup-db.sh /backup/location
```

## Adding Additional Services

To add more services behind the same Nginx reverse proxy:

1. **Edit Nginx configuration**:
   ```bash
   sudo nano /etc/nginx/sites-available/miniflux
   ```

2. **Add new location block**:
   ```nginx
   location /service2 {
       proxy_pass http://127.0.0.1:8082;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

3. **Reload Nginx**:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## Updating Miniflux

```bash
# Stop service
sudo systemctl stop miniflux

# Backup database
sudo ./scripts/backup-db.sh

# Download new binary
sudo wget -O /usr/local/bin/miniflux \
  https://github.com/miniflux/v2/releases/latest/download/miniflux-linux-amd64

# Set permissions
sudo chmod +x /usr/local/bin/miniflux
sudo chown miniflux:miniflux /usr/local/bin/miniflux

# Start service
sudo systemctl start miniflux

# Check status
sudo systemctl status miniflux
```

## Security Best Practices

1. **Change default passwords**: Update database password and admin password
2. **Firewall**: Only expose ports 80 and 443
3. **Keep updated**: Regularly update system packages and Miniflux
4. **Backup regularly**: Automate database backups
5. **Monitor logs**: Check logs regularly for errors or suspicious activity
6. **SSL/TLS**: Always use HTTPS in production
7. **File permissions**: Ensure config files are readable only by root

## Support and Resources

- **Miniflux Documentation**: https://miniflux.app/docs/
- **Miniflux GitHub**: https://github.com/miniflux/v2
- **Nginx Documentation**: https://nginx.org/en/docs/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/

## File Locations Summary

```
/etc/miniflux.conf              # Miniflux configuration
/etc/systemd/system/miniflux.service  # Systemd service file
/usr/local/bin/miniflux         # Miniflux binary
/etc/nginx/sites-available/miniflux  # Nginx configuration
/var/log/nginx/miniflux-*.log   # Nginx logs
/run/miniflux/                  # Miniflux runtime directory
```

## License

This deployment package follows the same license as Miniflux (Apache 2.0).
