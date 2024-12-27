# Quick Deployment Guide

## 1. Initial Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs postgresql postgresql-contrib nginx
sudo npm install -g pm2
```

## 2. Database Setup
```bash
# Setup PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE intercom_directory;"
sudo -u postgres psql -c "CREATE USER intercom_admin WITH ENCRYPTED PASSWORD 'your_secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE intercom_directory TO intercom_admin;"
```

## 3. Application Setup
```bash
# Setup application
sudo mkdir -p /opt/intercom-directory
sudo chown -R $USER:$USER /opt/intercom-directory
git clone https://your-repository-url.git /opt/intercom-directory
cd /opt/intercom-directory

# Install and build
npm install
npm run build

# Create .env file
echo "DATABASE_URL=postgresql://intercom_admin:your_secure_password@localhost:5432/intercom_directory
NODE_ENV=production" > .env
```

## 4. Configure Nginx
```bash
# Create Nginx config
sudo tee /etc/nginx/sites-available/intercom-directory <<EOF
server {
    listen 80;
    server_name your-domain.com;
    root /opt/intercom-directory/dist;
    
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/intercom-directory /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

## 5. Start Application
```bash
# Start API with PM2
cd /opt/intercom-directory
pm2 start api/server.js --name "intercom-api"
pm2 startup
pm2 save

# Setup firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

## 6. SSL Setup (Optional)
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Common Commands

### Maintenance
```bash
# View logs
pm2 logs intercom-api

# Update application
cd /opt/intercom-directory
git pull
npm install
npm run build
pm2 restart intercom-api

# Backup database
pg_dump -U postgres intercom_directory > backup.sql
```

### Troubleshooting
```bash
# Check API status
pm2 status

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart services
sudo systemctl restart nginx
pm2 restart all
```

Remember to:
1. Replace `your_secure_password` with a strong password
2. Replace `your-domain.com` with your domain/IP
3. Replace repository URL with your actual URL
4. Secure your server with proper firewall rules
5. Regularly backup your database