#!/bin/bash
# Quick Deployment Script for BinaryDev Infrastructure
# Run this on a fresh server for fully automated setup

set -e

echo "🚀 BinaryDev Infrastructure - Automated Deployment"
echo "==================================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found!"
    echo "Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ .env created - Please edit passwords before continuing!"
        echo ""
        echo "Edit .env and change:"
        echo "  - MONGO_INITDB_ROOT_PASSWORD"
        echo "  - POSTGRES_PASSWORD"
        echo "  - REDIS_PASSWORD"
        echo "  - RABBITMQ_PASSWORD"
        echo "  - QDRANT_API_KEY"
        echo ""
        read -p "Press Enter after editing .env..."
    else
        echo "❌ .env.example not found!"
        exit 1
    fi
fi

# Load environment variables
echo "📋 Loading environment variables..."
export $(cat .env | grep -v '^#' | xargs)

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Install Docker first: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose is installed
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed!"
    echo "Install Docker Compose plugin"
    exit 1
fi

echo "✅ Docker and Docker Compose found"

# Create Docker network if not exists
echo ""
echo "🌐 Setting up Docker network..."
if docker network ls | grep -q "${NETWORK_NAME:-binarydev}"; then
    echo "✅ Network ${NETWORK_NAME:-binarydev} already exists"
else
    docker network create --driver bridge ${NETWORK_NAME:-binarydev}
    echo "✅ Network ${NETWORK_NAME:-binarydev} created"
fi

echo ""
if [ "${USE_MONGO_KEYFILE}" = "true" ]; then
    echo "🔐 Setting up MongoDB keyfile (auth in RS)..."
    if [ ! -f config/mongodb/mongodb-keyfile ]; then
            mkdir -p config/mongodb
            openssl rand -base64 756 > config/mongodb/mongodb-keyfile
            chmod 400 config/mongodb/mongodb-keyfile
            echo "✅ MongoDB keyfile generated"
    else
            echo "✅ MongoDB keyfile exists"
    fi
else
    echo "🔐 Skipping MongoDB keyfile (auth not forced at startup)."
fi

# Create necessary directories
echo ""
echo "📁 Creating directories..."
mkdir -p data/mongodb data/postgresql data/redis data/qdrant data/rabbitmq data/traefik
mkdir -p logs/mongodb logs/postgresql logs/redis logs/rabbitmq logs/traefik
mkdir -p config/mongodb config/postgresql
echo "✅ Directories created"

# Start services
echo ""
echo "🚀 Starting all services..."
echo "This will take ~60 seconds for MongoDB to fully initialize..."
docker compose up -d

# Show status
echo ""
echo "⏳ Waiting for services to start (15 seconds)..."
sleep 15

echo ""
echo "📊 Service Status:"
docker compose ps

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "📝 Next Steps:"
echo "  1. Wait 60 seconds for MongoDB replica set to fully initialize"
echo "  2. Check MongoDB status: make mongodb-status"
echo "  3. View logs: make logs-mongodb"
echo "  4. Check all services: docker compose ps"
echo ""
echo "🔌 Connection Strings:"
echo "  MongoDB:    mongodb://${MONGO_INITDB_ROOT_USERNAME}:****@${MONGO_RS_MEMBER_HOST:-$(hostname -I | awk '{print $1}' || echo 'localhost'):${MONGO_DB_PORT}}/binarydb?replicaSet=${MONGO_REPLICA_SET_NAME:-rs0}&authSource=admin"
echo "  PostgreSQL: postgresql://${POSTGRES_USER}:****@$(hostname -I | awk '{print $1}' || echo 'localhost'):${POSTGRES_PORT}/binarydb"
echo "  Redis:      redis://:****@$(hostname -I | awk '{print $1}' || echo 'localhost'):${REDIS_PORT}"
echo "  RabbitMQ:   amqp://${RABBITMQ_USER}:****@$(hostname -I | awk '{print $1}' || echo 'localhost'):${RABBITMQ_PORT}/${RABBITMQ_VHOST}"
echo ""
echo "🌐 Management UIs:"
echo "  RabbitMQ:   http://$(hostname -I | awk '{print $1}' || echo 'localhost'):${RABBITMQ_MANAGEMENT_PORT}"
echo "  BullMQ:     http://$(hostname -I | awk '{print $1}' || echo 'localhost'):${BULLMQ_BOARD_PORT}"
echo "  Traefik:    http://$(hostname -I | awk '{print $1}' || echo 'localhost'):8080"
echo ""
echo "✅ All services running! MongoDB will be fully ready in ~60 seconds."
