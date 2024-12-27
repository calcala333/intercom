# Deployment Guide for Ubuntu Server

## Prerequisites

1. Ubuntu Server 20.04 LTS or newer
2. Root or sudo access
3. Domain name (optional)

## 1. System Updates

```bash
sudo apt update
sudo apt upgrade -y
```

## 2. Install Required Software

```bash
# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install Nginx
sudo apt install -y nginx

# Install PM2 for process management
sudo npm install -g pm2
```

## 3. Configure PostgreSQL

```bash
# Switch to postgres user
sudo -i -u postgres

# Create database and user
psql -c "CREATE DATABASE intercom_directory;"
psql -c "CREATE USER intercom_admin WITH ENCRYPTED PASSWORD 'your_secure_password';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE intercom_directory TO intercom_admin;"

# Exit postgres user
exit
```

## 4. Application Setup

```bash
# Create application directory
sudo mkdir -p /opt/intercom-directory
sudo chown -R $USER:$USER /opt/intercom-directory

# Clone your application (replace with your repository URL)
git clone https://your-repository-url.git /opt/intercom-directory
cd /opt/intercom-directory

# Install dependencies
npm install

# Build the application
npm run build
```

## 5. Environment Configuration

Create `.env` file in `/opt/intercom-directory`:

```env
# Database Configuration
DATABASE_URL=postgresql://intercom_admin:your_secure_password@localhost:5432/intercom_directory
NODE_ENV=production
```

## 6. Configure Nginx

Create `/etc/nginx/sites-available/intercom-directory`:

```nginx
server {
    listen 80;
    server_name your-domain.com; # Replace with your domain or IP

    root /opt/intercom-directory/dist;
    index index.html;

    # API Proxy
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Static files
    location / {
        try_files $uri $uri/ /index.html;
        expires -1;
        add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/intercom-directory /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default # Remove default site
sudo nginx -t # Test configuration
sudo systemctl restart nginx
```

## 7. Start Application Services

```bash
# Start API server with PM2
cd /opt/intercom-directory
pm2 start api/server.js --name "intercom-api"

# Make PM2 start on boot
pm2 startup
pm2 save
```

## 8. Database Migration

```bash
# Run database migrations
cd /opt/intercom-directory
node api/db.js
```

## 9. Security Setup

```bash
# Configure firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

## 10. SSL Configuration (Optional but Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com
```

## Maintenance Commands

```bash
# View API logs
pm2 logs intercom-api

# Restart API
pm2 restart intercom-api

# Update application
cd /opt/intercom-directory
git pull
npm install
npm run build
pm2 restart intercom-api

# Backup database
pg_dump -U postgres intercom_directory > backup.sql

# Restore database
psql -U postgres intercom_directory < backup.sql
```

## Troubleshooting

1. Check API logs:
```bash
pm2 logs intercom-api
```

2. Check Nginx logs:
```bash
sudo tail -f /var/log/nginx/error.log
```

3. Check database connection:
```bash
psql -U intercom_admin -h localhost -d intercom_directory
```

4. Restart services:
```bash
sudo systemctl restart nginx
pm2 restart all
```