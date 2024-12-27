#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Intercom Directory Installation...${NC}"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required dependencies
echo -e "${YELLOW}Installing required dependencies...${NC}"
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg

# Install Docker
echo -e "${YELLOW}Installing Docker...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
echo -e "${YELLOW}Starting Docker service...${NC}"
systemctl start docker
systemctl enable docker

# Create directory for application
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p /opt/intercom-directory
cd /opt/intercom-directory

# Copy application files
echo -e "${YELLOW}Copying application files...${NC}"
cp -r * /opt/intercom-directory/

# Create environment file
echo -e "${YELLOW}Creating environment file...${NC}"
cat > .env << EOL
# Database Configuration
POSTGRES_USER=admin
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=intercom_directory

# Application Configuration
NODE_ENV=production
EOL

# Set correct permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R root:root /opt/intercom-directory
chmod -R 755 /opt/intercom-directory

# Start the containers
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker compose up -d

echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}The application is now running and will start automatically on system boot.${NC}"
echo -e "${YELLOW}You can access the application at: http://localhost${NC}"

echo -e "\nDefault admin credentials:"
echo -e "${YELLOW}Username: ${NC}admin"
echo -e "${YELLOW}Password: ${NC}admin123"
echo -e "\n${RED}IMPORTANT: Please change these credentials after first login!${NC}"

echo -e "\nUseful commands:"
echo -e "${YELLOW}- View logs: ${NC}docker compose logs -f"
echo -e "${YELLOW}- Restart application: ${NC}docker compose restart"
echo -e "${YELLOW}- Stop application: ${NC}docker compose down"
echo -e "${YELLOW}- Start application: ${NC}docker compose up -d"