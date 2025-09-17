.PHONY: up down logs restart setup-dirs down-clean pull build status logs-mongodb logs-redis logs-qdrant logs-postgresql create-network setup-ubuntu setup-firewall-ubuntu

# Detect OS
UNAME := $(shell uname)

# Detect Docker Compose command
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null || echo "docker compose")

# Create necessary directories
setup-dirs:
	@echo "Creating necessary directories..."
	@mkdir -p data/mongodb data/redis data/qdrant data/postgresql
	@mkdir -p logs
ifeq ($(UNAME), Linux)
	@echo "Setting Linux permissions..."
	@chmod -R 755 data/ logs/
	@chown -R $(USER):$(USER) data/ logs/ 2>/dev/null || true
endif
	@echo "Directories created successfully!"

# Ubuntu specific setup
setup-ubuntu:
	@echo "Running Ubuntu setup script..."
	@./setup-ubuntu.sh

# Ubuntu firewall setup
setup-firewall-ubuntu:
	@echo "Setting up Ubuntu firewall for database ports..."
	@sudo ufw allow 5432/tcp comment "PostgreSQL"
	@sudo ufw allow 27017/tcp comment "MongoDB"
	@sudo ufw allow 6379/tcp comment "Redis"
	@sudo ufw allow 6333/tcp comment "Qdrant"
	@sudo ufw allow 80/tcp comment "HTTP"
	@sudo ufw allow 443/tcp comment "HTTPS"
	@sudo ufw allow 8080/tcp comment "Traefik Dashboard"
	@echo "Firewall rules added successfully!"

# Start all services
up: setup-dirs
	$(DOCKER_COMPOSE) up -d

# Stop and remove all services
down:
	$(DOCKER_COMPOSE) down

# Stop, remove, and clean up volumes (use with caution - deletes data)
down-clean:
	$(DOCKER_COMPOSE) down -v
ifeq ($(UNAME), Linux)
	@sudo rm -rf data/ logs/ 2>/dev/null || rm -rf data/ logs/
else
	@rm -rf data/ logs/
endif

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