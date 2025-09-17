#!/bin/bash

echo "🚀 Setting up BinaryDev Server on Ubuntu..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please don't run this script as root. Run as normal user with sudo access."
    exit 1
fi

# Update system
print_status "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install prerequisites
print_status "Installing prerequisites..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    ufw

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Remove old Docker versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_success "Docker installed successfully!"
else
    print_success "Docker is already installed!"
fi

# Install Docker Compose (standalone)
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    print_success "Docker Compose installed successfully!"
else
    print_success "Docker Compose is already installed!"
fi

# Add user to docker group
print_status "Adding user to docker group..."
sudo usermod -aG docker $USER

# Start and enable Docker service
print_status "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Setup firewall
print_status "Setting up firewall..."
sudo ufw --force enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow database ports
sudo ufw allow 5432/tcp comment "PostgreSQL"
sudo ufw allow 27017/tcp comment "MongoDB"
sudo ufw allow 6379/tcp comment "Redis"
sudo ufw allow 6333/tcp comment "Qdrant"

# Allow HTTP/HTTPS for Traefik
sudo ufw allow 80/tcp comment "HTTP"
sudo ufw allow 443/tcp comment "HTTPS"
sudo ufw allow 8080/tcp comment "Traefik Dashboard"

print_success "Firewall configured!"

# Create necessary directories
print_status "Creating project directories..."
mkdir -p data/{mongodb,redis,qdrant,postgresql}
mkdir -p logs

# Set proper permissions
chmod -R 755 data/ logs/
chown -R $USER:$USER data/ logs/

print_success "Directories created!"

# Copy environment file
if [ ! -f .env ]; then
    cp .env.example .env
    print_success "Created .env file from .env.example"
else
    print_warning ".env file already exists, skipping..."
fi

# Create systemctl service (optional)
print_status "Creating systemd service for BinaryDev..."
sudo tee /etc/systemd/system/binarydev.service > /dev/null <<EOF
[Unit]
Description=BinaryDev Server Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$(pwd)
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=$USER
Group=docker

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable binarydev.service

print_success "Systemd service created!"

# Show final instructions
echo ""
echo "🎉 Ubuntu setup complete!"
echo ""
echo "Next steps:"
echo "1. Logout and login again to apply docker group changes:"
echo "   ${YELLOW}logout${NC}"
echo ""
echo "2. Or run this command to apply group changes:"
echo "   ${YELLOW}newgrp docker${NC}"
echo ""
echo "3. Start services:"
echo "   ${YELLOW}make up${NC}"
echo ""
echo "4. Check status:"
echo "   ${YELLOW}make status${NC}"
echo ""
echo "5. Or use systemd service:"
echo "   ${YELLOW}sudo systemctl start binarydev${NC}"
echo ""
echo "Access points:"
echo "- PostgreSQL: localhost:5432"
echo "- MongoDB: localhost:27017"
echo "- Redis: localhost:6379"
echo "- Qdrant: localhost:6333"
echo "- Traefik Dashboard: localhost:8080"
echo ""
print_success "Setup completed successfully!"
