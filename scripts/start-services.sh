#!/bin/bash

echo "🚀 Starting BinaryDev Services..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    print_status "Creating .env from .env.example..."
    cp .env.example .env
    print_success ".env file created"
fi

# Load environment variables
source .env

# Detect Docker Compose command
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    print_error "Docker Compose not found. Please install Docker Compose."
    exit 1
fi
print_status "Using Docker Compose command: ${DOCKER_COMPOSE}"

# Check if Docker is running
print_status "Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi
print_success "Docker is running"

# Create network if it doesn't exist
print_status "Setting up Docker network..."
docker network create ${NETWORK_NAME} 2>/dev/null && print_success "Network ${NETWORK_NAME} created" || print_warning "Network ${NETWORK_NAME} already exists"

# Create necessary directories
print_status "Creating data directories..."
mkdir -p data/{mongodb,redis,qdrant,postgresql}
mkdir -p logs
print_success "Directories created"

# Set proper permissions for PostgreSQL configuration files
print_status "Setting PostgreSQL configuration permissions..."
chmod 600 config/postgresql/pg_hba.conf 2>/dev/null || print_warning "pg_hba.conf not found"
chmod 600 config/postgresql/postgresql.conf 2>/dev/null || print_warning "postgresql.conf not found"
chmod 644 config/postgresql/init.sql 2>/dev/null || print_warning "init.sql not found"
print_success "PostgreSQL configuration permissions set"

# Check if we're on Ubuntu and setup firewall
if command -v ufw >/dev/null 2>&1; then
    print_status "Setting up Ubuntu firewall..."
    sudo ufw allow 5432/tcp >/dev/null 2>&1  # PostgreSQL
    sudo ufw allow 27017/tcp >/dev/null 2>&1 # MongoDB
    sudo ufw allow 6379/tcp >/dev/null 2>&1  # Redis
    sudo ufw allow 6333/tcp >/dev/null 2>&1  # Qdrant
    sudo ufw allow 80/tcp >/dev/null 2>&1    # HTTP
    sudo ufw allow 443/tcp >/dev/null 2>&1   # HTTPS
    sudo ufw allow 8080/tcp >/dev/null 2>&1  # Traefik Dashboard
    print_success "Firewall configured for Ubuntu"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_warning "Detected Linux, but ufw not found. Please ensure firewall allows the required ports:"
    print_warning "  - PostgreSQL: 5432/tcp"
    print_warning "  - MongoDB: 27017/tcp"
    print_warning "  - Redis: 6379/tcp"
    print_warning "  - Qdrant: 6333/tcp"
    print_warning "  - HTTP: 80/tcp, HTTPS: 443/tcp, Traefik: 8080/tcp"
fi

# PostgreSQL Fix for lc_collate error
print_status "Checking PostgreSQL configuration..."
if docker ps -q -f name=postgresql >/dev/null 2>&1; then
    print_warning "PostgreSQL container exists, checking for lc_collate issues..."
    if docker logs postgresql 2>&1 | grep -q "unrecognized configuration parameter.*lc_collate"; then
        print_warning "Found lc_collate error, fixing PostgreSQL..."
        ${DOCKER_COMPOSE} stop postgresql
        print_status "Removing problematic PostgreSQL data..."
        rm -rf data/postgresql
        mkdir -p data/postgresql
        print_success "PostgreSQL reset complete"
    fi
fi

# Start services
print_status "Starting all services..."
${DOCKER_COMPOSE} up -d

# Wait for services to be ready
print_status "Waiting for services to initialize..."
sleep 10

# Check PostgreSQL specifically
print_status "Checking PostgreSQL status..."
if docker exec postgresql psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();" >/dev/null 2>&1; then
    print_success "PostgreSQL is ready"
    
    # Create additional database if specified
    if [ ! -z "${POSTGRES_DB_SECONDARY:-}" ]; then
        print_status "Creating secondary database: ${POSTGRES_DB_SECONDARY}"
        docker exec postgresql psql -U ${POSTGRES_USER} -d postgres -c "CREATE DATABASE ${POSTGRES_DB_SECONDARY};" 2>/dev/null || print_warning "Secondary database might already exist"
    fi
else
    print_warning "PostgreSQL not ready yet, check logs: make logs-postgresql"
fi

echo ""
print_success "Services started successfully!"
echo ""
print_status "🌐 Access your services:"
echo "   - Traefik Dashboard: http://localhost:8080"

# Show service URLs
if [ -f .env ]; then
    grep "_DOMAIN=" .env 2>/dev/null | while IFS='=' read -r key value; do
        if [ ! -z "$value" ]; then
            service_name=$(echo "$key" | sed 's/_DOMAIN//' | tr '[:upper:]' '[:lower:]')
            echo "   - ${service_name}: https://${value}"
        fi
    done
fi

echo ""
print_status "🗄️ Database access:"
echo "   - PostgreSQL: localhost:${POSTGRES_PORT} (User: ${POSTGRES_USER}, DB: ${POSTGRES_DB})"
echo "   - MongoDB: localhost:${MONGO_DB_PORT} (User: ${MONGO_INITDB_ROOT_USERNAME}, DB: ${MONGO_INITDB_DATABASE})"
echo "   - Redis: localhost:${REDIS_PORT} (Password protected)"
echo "   - Qdrant: localhost:${QDRANT_PORT} (API Key protected)"

echo ""
print_status "📋 Useful commands:"
echo "   - Check status: make status"
echo "   - View logs: make logs"
echo "   - PostgreSQL logs: make logs-postgresql"
echo "   - Stop services: make down"

# Show PostgreSQL connection info for external access
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "YOUR_SERVER_IP")
echo ""
print_status "🔗 External access (pgAdmin/DBeaver):"
echo "   Host: ${SERVER_IP}"
echo "   Port: ${POSTGRES_PORT}"
echo "   Database: ${POSTGRES_DB}"
echo "   Username: ${POSTGRES_USER}"
echo "   Password: ${POSTGRES_PASSWORD}"
echo ""
print_status "🔧 Troubleshooting commands:"
echo "   - Check PostgreSQL logs: docker logs postgresql"
echo "   - Test connection: docker exec postgresql psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c 'SELECT version();'"
echo "   - Check firewall: sudo ufw status"
echo "   - Check Docker networks: docker network ls"
echo "   - Test port: nc -zv ${SERVER_IP} ${POSTGRES_PORT}"
