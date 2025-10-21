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

# MongoDB Replica Set commands
mongodb-init-replica:
	@echo "🔧 Initializing MongoDB Replica Set..."
	@chmod +x scripts/init-mongodb-replica.sh
	@./scripts/init-mongodb-replica.sh

mongodb-status:
	@echo "📊 MongoDB Replica Set Status:"
	@docker exec mongodb mongosh -u $$(grep '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2) \
		-p $$(grep '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2) \
		--authenticationDatabase admin --quiet --eval "rs.status()"

mongodb-config:
	@echo "⚙️ MongoDB Replica Set Configuration:"
	@docker exec mongodb mongosh -u $$(grep '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2) \
		-p $$(grep '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2) \
		--authenticationDatabase admin --quiet --eval "rs.conf()"

mongodb-shell:
	@docker exec -it mongodb mongosh -u $$(grep '^MONGO_INITDB_ROOT_USERNAME=' .env | cut -d'=' -f2) \
		-p $$(grep '^MONGO_INITDB_ROOT_PASSWORD=' .env | cut -d'=' -f2) \
		--authenticationDatabase admin

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

# BullMQ specific commands
logs-bullmq:
	@$(DOCKER_COMPOSE) logs -f bullmq-board

restart-bullmq:
	@$(DOCKER_COMPOSE) restart bullmq-board

bullmq-ui:
	@echo "🎯 Opening BullMQ Board UI..."
	@if [ -f .env ]; then \
		PORT=$$(grep '^BULLMQ_BOARD_PORT=' .env | cut -d'=' -f2); \
		PORT=$${PORT:-3001}; \
		open http://localhost:$$PORT 2>/dev/null || xdg-open http://localhost:$$PORT 2>/dev/null || echo "Please open: http://localhost:$$PORT"; \
	else \
		echo "Please open: http://localhost:3001"; \
	fi

# RabbitMQ specific commands
logs-rabbitmq:
	@$(DOCKER_COMPOSE) logs -f rabbitmq

restart-rabbitmq:
	@$(DOCKER_COMPOSE) restart rabbitmq

rabbitmq-ui:
	@echo "🐰 Opening RabbitMQ Management UI..."
	@if [ -f .env ]; then \
		PORT=$$(grep '^RABBITMQ_MANAGEMENT_PORT=' .env | cut -d'=' -f2); \
		PORT=$${PORT:-15672}; \
		open http://localhost:$$PORT 2>/dev/null || xdg-open http://localhost:$$PORT 2>/dev/null || echo "Please open: http://localhost:$$PORT"; \
	else \
		echo "Please open: http://localhost:15672"; \
	fi

# Backup databases
backup:
	@chmod +x scripts/backup-databases.sh
	@./scripts/backup-databases.sh all

backup-postgresql:
	@chmod +x scripts/backup-databases.sh
	@./scripts/backup-databases.sh postgresql

backup-mongodb:
	@chmod +x scripts/backup-databases.sh
	@./scripts/backup-databases.sh mongodb

backup-redis:
	@chmod +x scripts/backup-databases.sh
	@./scripts/backup-databases.sh redis