#!/bin/bash

echo "Starting Docker services..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Create network if it doesn't exist
source .env
docker network create ${NETWORK_NAME} 2>/dev/null || echo "Network ${NETWORK_NAME} already exists"

# Start services
echo "Starting all services..."
docker-compose up -d

echo ""
echo "✅ Services started successfully!"
echo ""
echo "🌐 Access your services:"
echo "   - Traefik Dashboard: http://localhost:8080"

# Show service URLs
grep "_DOMAIN=" .env | while IFS='=' read -r key value; do
    service_name=$(echo "$key" | sed 's/_DOMAIN//' | tr '[:upper:]' '[:lower:]')
    echo "   - ${service_name}: https://${value}"
done

echo ""
echo "📊 Check status: docker-compose ps"
echo "📝 View logs: docker-compose logs -f [service-name]"
echo "🛑 Stop services: docker-compose down"
