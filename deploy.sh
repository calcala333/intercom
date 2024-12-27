#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

# Prompt for configuration
read -p "Enter domain name (or server IP): " DOMAIN_NAME
read -p "Enter PostgreSQL password: " DB_PASSWORD
read -p "Enter Git repository URL: " REPO_URL

print_message "Starting deployment process..."

# 1. System Updates
print_message "Updating system packages..."
apt update && apt upgrade -y

# 2. Install Required Software
print_message "Installing required packages..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs postgresql postgresql-contrib nginx

# Install PM2 globally
npm install -g pm2

# 3. Configure PostgreSQL
print_message "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE intercom_directory;"
sudo -u postgres psql -c "CREATE USER intercom_admin WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE intercom_directory TO intercom_admin;"

# 4. Application Setup
print_message "Setting up application..."
mkdir -p /opt/intercom-directory
chown -R $SUDO_USER:$SUDO_USER /opt/intercom-directory
su - $SUDO_USER <<EOF
git clone $REPO_URL /opt/intercom-directory
cd /opt/intercom-directory
npm install
npm run build
EOF

# 5. Environment Configuration
print_message "Creating environment configuration..."
cat > /opt/intercom-directory/.env <<EOF
DATABASE_URL=postgresql://intercom_admin:$DB_PASSWORD@localhost:5432/intercom_directory
NODE_ENV=production
EOF

# 6. Configure Nginx
print_message "Configuring Nginx..."
cat > /etc/nginx/sites-available/intercom-directory <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root /opt/intercom-directory/dist;
    
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
        expires -1;
        add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
}
EOF

ln -sf /etc/nginx/sites-available/intercom-directory /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# 7. Start Application
print_message "Starting application..."
cd /opt/intercom-directory
su - $SUDO_USER <<EOF
cd /opt/intercom-directory
pm2 start api/server.js --name "intercom-api"
pm2 startup
pm2 save
EOF

# 8. Configure Firewall
print_message "Configuring firewall..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw --force enable

# 9. SSL Setup (Optional)
print_message "Would you like to setup SSL with Let's Encrypt? (y/n)"
read -r setup_ssl
if [ "$setup_ssl" = "y" ]; then
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $DOMAIN_NAME
fi

# Create backup script
print_message "Creating backup script..."
cat > /opt/intercom-directory/backup.sh <<EOF
#!/bin/bash
BACKUP_DIR="/opt/intercom-directory/backups"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR

# Backup database
pg_dump -U postgres intercom_directory > \$BACKUP_DIR/db_backup_\$TIMESTAMP.sql

# Backup application files
tar -czf \$BACKUP_DIR/app_backup_\$TIMESTAMP.tar.gz /opt/intercom-directory

# Keep only last 5 backups
cd \$BACKUP_DIR
ls -t db_backup_* | tail -n +6 | xargs -r rm
ls -t app_backup_* | tail -n +6 | xargs -r rm
EOF

chmod +x /opt/intercom-directory/backup.sh

# Setup daily backup cron job
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/intercom-directory/backup.sh") | crontab -

print_message "Deployment completed successfully!"
echo -e "\nImportant next steps:"
echo "1. Test the application at http://$DOMAIN_NAME"
echo "2. Configure automatic backups"
echo "3. Monitor the logs using: pm2 logs intercom-api"
echo "4. Update your DNS records if using a domain name"

# Print credentials
echo -e "\nDatabase Credentials:"
echo "Database: intercom_directory"
echo "Username: intercom_admin"
echo "Password: $DB_PASSWORD"