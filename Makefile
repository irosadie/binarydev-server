.PHONY: up down logs restart setup-dirs down-clean pull build status logs-mongodb logs-redis logs-qdrant logs-postgresql create-network start

# Detect Docker Compose command
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
ifndef DOCKER_COMPOSE
    DOCKER_COMPOSE := docker compose
endif

# Start all services with automatic fixes
start:
	@chmod +x scripts/start-services.sh
	@./scripts/start-services.sh

# Create necessary directories
setup-dirs:
	@echo "Creating necessary directories..."
	@mkdir -p data/mongodb data/redis data/qdrant data/postgresql
	@mkdir -p logs
	@echo "Directories created successfully!"

# Start all services (simple)
up: setup-dirs
	$(DOCKER_COMPOSE) up -d

# Stop and remove all services
down:
	$(DOCKER_COMPOSE) down

# Stop, remove, and clean up volumes (use with caution - deletes data)
down-clean:
	$(DOCKER_COMPOSE) down -v

# Restart all services
restart:
	$(DOCKER_COMPOSE) restart

# View logs
logs:
	$(DOCKER_COMPOSE) logs -f

logs-mongodb:
	$(DOCKER_COMPOSE) logs -f mongodb

logs-redis:
	$(DOCKER_COMPOSE) logs -f redis

logs-qdrant:
	$(DOCKER_COMPOSE) logs -f qdrant

logs-postgresql:
	$(DOCKER_COMPOSE) logs -f postgresql

# Pull latest images
pull:
	$(DOCKER_COMPOSE) pull

# Build and start (if you have custom builds)
build:
	$(DOCKER_COMPOSE) up -d --build

# Create external Docker network from .env
create-network:
	@if [ ! -f .env ]; then \
		echo ".env file not found"; \
		exit 1; \
	fi
	@NETWORK_NAME=$$(grep '^NETWORK_NAME=' .env | cut -d'=' -f2); \
	if [ -z "$$NETWORK_NAME" ]; then \
		echo "NETWORK_NAME is not set in .env"; \
		exit 1; \
	fi; \
	if ! docker network ls --format "{{.Name}}" | grep -q "^$$NETWORK_NAME$$"; then \
		docker network create --driver bridge $$NETWORK_NAME; \
		echo "Network $$NETWORK_NAME created successfully."; \
	else \
		echo "Network $$NETWORK_NAME already exists."; \
	fi

# Check status
status:
	$(DOCKER_COMPOSE) ps