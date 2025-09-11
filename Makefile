.PHONY: up down logs restart setup-dirs ssl-setup firewall-setup down-clean pull build status logs-mongodb logs-redis

# Setup firewall (run with sudo)
firewall-setup:
	sudo bash scripts/firewall-setup.sh

# Create necessary directories
setup-dirs:
	mkdir -p data/mongodb data/redis logs

# Start all services
up: setup-dirs
	docker compose up -d

# Stop and remove all services
down:
	docker compose down

# Stop, remove, and clean up volumes (use with caution - deletes data)
down-clean:
	docker compose down -v

# Restart all services
restart:
	docker compose restart

# View logs
logs:
	docker compose logs -f

logs-mongodb:
	docker compose logs -f mongodb

logs-redis:
	docker compose logs -f redis

# Pull latest images
pull:
	docker compose pull

# Build and start (if you have custom builds)
build:
	docker compose up -d --build

# Check status
status:
	docker compose ps