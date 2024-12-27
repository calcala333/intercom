# Intercom Directory Deployment

## Quick Deploy

1. Copy the deployment script to your Ubuntu server
2. Make it executable:
   ```bash
   chmod +x deploy.sh
   ```
3. Run the script:
   ```bash
   sudo ./deploy.sh
   ```

4. Follow the prompts to enter:
   - Domain name or server IP
   - PostgreSQL password
   - Git repository URL

The script will automatically:
- Install all required software
- Configure PostgreSQL
- Set up Nginx
- Configure SSL (optional)
- Start the application
- Set up automatic backups

## Manual Deployment

If you prefer to deploy manually, follow the steps in DEPLOYMENT.md

## Maintenance

### Backup
```bash
# Manual backup
/opt/intercom-directory/backup.sh

# View latest backups
ls -l /opt/intercom-directory/backups
```

### Logs
```bash
# View application logs
pm2 logs intercom-api

# View Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Updates
```bash
cd /opt/intercom-directory
git pull
npm install
npm run build
pm2 restart intercom-api
```