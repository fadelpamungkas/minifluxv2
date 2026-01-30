# Quick Start Guide for Dalang.io

This is a simplified guide specifically for Dalang.io users with web terminal access.

## Your Server Information

- **Public Domain**: `38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io`
- **Local IP**: `10.70.0.62`
- **Access Method**: Web Terminal via Dalang.io dashboard

## Step-by-Step Installation

### Step 1: Access Your Server

1. Log in to **Dalang.io** dashboard
2. Navigate to your server/VPS
3. Open the **Web Terminal** (usually a button like "Terminal" or "Console")

### Step 2: Upload Deployment Files

You have several options:

#### Option A: Upload via Web Terminal File Manager
1. Use Dalang.io's file manager/upload feature
2. Upload the entire `deployment/` folder to `/tmp/deployment/` on the server

#### Option B: Use SCP from Your Local Machine
```bash
# From your local machine (if SSH is enabled)
scp -r deployment/ root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io:/tmp/
```

#### Option C: Download from GitHub/URL
```bash
# In web terminal, if you have the files in a repo or file host
cd /tmp
# Download your deployment files (adjust URL as needed)
wget https://your-file-host.com/deployment.tar.gz
tar -xzf deployment.tar.gz
```

### Step 3: Run Installation Script

In the web terminal:

```bash
# Navigate to deployment directory
cd /tmp/deployment

# Make scripts executable (if needed)
chmod +x scripts/*.sh
chmod +x postgresql/setup.sh

# Run the automated installation
sudo ./scripts/install.sh
```

The script will:
- Install required packages (Nginx, PostgreSQL, Certbot)
- Download Miniflux binary
- Setup PostgreSQL database
- Configure systemd service
- Setup Nginx reverse proxy

### Step 4: Update Configuration

```bash
# Edit Miniflux configuration
sudo nano /etc/miniflux.conf
```

**Update these values:**
- `BASE_URL`: Already set to `https://38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io/miniflux`
- `DATABASE_URL`: Update password if you changed it during PostgreSQL setup

**Save and exit** (Ctrl+X, then Y, then Enter)

### Step 5: Setup SSL Certificate

```bash
# Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx -d 38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io
```

**Note**: If certbot fails, Dalang.io might handle SSL automatically. Check Dalang.io documentation.

### Step 6: Start Services

```bash
# Start Miniflux
sudo systemctl start miniflux

# Check status
sudo systemctl status miniflux

# Enable auto-start on boot
sudo systemctl enable miniflux
```

### Step 7: Verify Installation

1. **Check service status**:
   ```bash
   sudo systemctl status miniflux
   sudo systemctl status nginx
   sudo systemctl status postgresql
   ```

2. **Check logs**:
   ```bash
   sudo journalctl -u miniflux -f
   ```

3. **Access Miniflux**:
   Open in browser: `https://38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io/miniflux`

## Troubleshooting

### If Web Terminal Doesn't Work

1. Check if you have root/sudo access
2. Try accessing via SSH if available:
   ```bash
   ssh root@38264e67-5d48-4757-85a4-6985d9aa491a.svc.dalang.io
   ```

### If File Upload Fails

Use alternative methods:
- **Git**: Clone repository if you have it on GitHub/GitLab
- **SCP**: Use from your local machine if SSH is enabled
- **Manual copy-paste**: Copy file contents and create files manually

### If Installation Script Fails

Run steps manually:
```bash
# 1. Install packages
sudo apt update
sudo apt install -y nginx postgresql-15 certbot python3-certbot-nginx

# 2. Setup PostgreSQL
sudo ./postgresql/setup.sh

# 3. Download Miniflux
sudo wget -O /usr/local/bin/miniflux \
  https://github.com/miniflux/v2/releases/latest/download/miniflux-linux-amd64
sudo chmod +x /usr/local/bin/miniflux

# 4. Setup user
sudo ./scripts/setup-miniflux-user.sh

# 5. Configure Miniflux
sudo cp miniflux/miniflux.conf /etc/miniflux.conf
sudo nano /etc/miniflux.conf  # Edit as needed

# 6. Setup systemd
sudo cp miniflux/miniflux.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable miniflux

# 7. Configure Nginx
sudo cp nginx/miniflux.conf /etc/nginx/sites-available/miniflux
sudo ln -s /etc/nginx/sites-available/miniflux /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 8. Start Miniflux
sudo systemctl start miniflux
```

## Common Commands

```bash
# View Miniflux logs
sudo journalctl -u miniflux -f

# Restart Miniflux
sudo systemctl restart miniflux

# Check Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Backup database
sudo ./scripts/backup-db.sh
```

## Need Help?

- Check main README.md for detailed documentation
- Check Miniflux logs: `sudo journalctl -u miniflux -n 50`
- Check Nginx logs: `sudo tail -f /var/log/nginx/miniflux-error.log`
