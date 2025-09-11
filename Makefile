.PHONY: up down logs restart setup-dirs down-clean pull build status logs-mongodb logs-redis

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

	docker compose up -d --build

# Build and start (if you have custom builds)
build:
	docker compose up -d --build

# Create external Docker network from .env
create-network:
	@if [ -f .env ]; then \
		export $(grep -v '^#' .env | xargs); \
		if [ -z "$$NETWORK_NAME" ]; then \
			echo "NETWORK_NAME is not set in .env"; exit 1; \
		fi; \
		docker network inspect $$NETWORK_NAME >/dev/null 2>&1 || \
			docker network create --driver bridge $$NETWORK_NAME; \
		echo "Network $$NETWORK_NAME is ready."; \
	else \
		echo ".env file not found"; exit 1; \
	fi

# Check status
status:
	docker compose ps