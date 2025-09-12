# BinaryDev Server Stack

Complete docker-compose stack untuk BinaryDev dengan MongoDB, Redis, dan Qdrant Vector Database.

## Quick Start

### 1. Setup
```bash
# Clone repository
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server

# Create network
make create-network

# Setup directories
make setup-dirs
```

### 2. Environment
Edit file `.env` sesuai kebutuhan:
```bash
NETWORK_NAME=binarydev
SSL_EMAIL=hi@binarydev.co.id

# MongoDB
MONGO_INITDB_ROOT_USERNAME=binarydev
MONGO_INITDB_ROOT_PASSWORD=5ayagantenG
MONGO_INITDB_DATABASE=binarydb
MONGO_DB_PORT=27017

# Redis
REDIS_PASSWORD=5ayagantenG
REDIS_PORT=6379

# Qdrant Vector Database
QDRANT_PORT=6333
QDRANT_API_KEY=binarydev_qdrant_key
```

### 3. Start Services
```bash
# Start all services
make up

# Check status
make status
```

## Services

### 🌐 Traefik (Reverse Proxy)
- **Ports**: 80, 443, 8080 (dashboard)
- **Features**: SSL certificates, load balancing
- **Dashboard**: http://localhost:8080

### 🍃 MongoDB
- **Port**: 27017
- **Features**: Replica set enabled
- **Authentication**: Username/password dari .env

### 🔴 Redis
- **Port**: 6379
- **Features**: Password protected, persistence enabled
- **Authentication**: Password dari .env

### 🔍 Qdrant Vector Database
- **Port**: 6333 (API)
- **Features**: API key authentication, persistent storage
- **Authentication**: API key dari .env

## Make Commands

### Basic Operations
```bash
make up           # Start all services
make down         # Stop all services
make restart      # Restart all services
make status       # Show service status
make logs         # View all logs
```

### Service-specific Commands
```bash
make logs-mongodb # MongoDB logs
make logs-redis   # Redis logs
make logs-qdrant  # Qdrant logs
```

### Utilities
```bash
make setup-dirs      # Create necessary directories
make create-network  # Create Docker network
make pull           # Pull latest images
make build          # Build and start
make down-clean     # Stop and remove volumes
```

## Qdrant Vector Database

### API Usage
Semua API call memerlukan API key di header:
```bash
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections
```

### Create Collection
```bash
curl -X PUT "http://localhost:6333/collections/my_collection" \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_API_KEY" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

### Insert Vector
```bash
curl -X PUT "http://localhost:6333/collections/my_collection/points" \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_API_KEY" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, ...],
        "payload": {"text": "example"}
      }
    ]
  }'
```

### Search Vectors
```bash
curl -X POST "http://localhost:6333/collections/my_collection/points/search" \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_API_KEY" \
  -d '{
    "vector": [0.1, 0.2, 0.3, ...],
    "limit": 10
  }'
```

## Directory Structure
```
├── data/
│   ├── mongodb/     # MongoDB data
│   ├── redis/       # Redis data
│   └── qdrant/      # Qdrant storage
├── logs/            # Service logs
├── scripts/         # Utility scripts
├── docker-compose.yml
├── Makefile
├── .env
└── README.md
```

## Security Features

### Qdrant
- ✅ API Key authentication
- ✅ Network isolation
- ✅ Persistent storage

### MongoDB
- ✅ Username/password authentication
- ✅ Replica set configuration
- ✅ Network isolation

### Redis
- ✅ Password authentication
- ✅ Protected mode
- ✅ Persistence enabled

### Traefik
- ✅ SSL certificates (Let's Encrypt)
- ✅ Access logs
- ✅ Security headers

## Troubleshooting

### Check Service Status
```bash
make status
```

### View Logs
```bash
make logs           # All services
make logs-qdrant    # Qdrant only
make logs-mongodb   # MongoDB only
make logs-redis     # Redis only
```

### Common Issues

#### Network Not Found
```bash
make create-network
```

#### Permission Denied
```bash
sudo chown -R $(whoami):$(whoami) data/ logs/
```

#### Port Already in Use
```bash
# Stop existing services
docker compose down
# Or change ports in .env
```

## Development

### Adding New Services
1. Edit `docker-compose.yml`
2. Add environment variables to `.env`
3. Update `setup-dirs` in `Makefile`
4. Update this README

### Custom Configuration
- MongoDB: Edit replica set config in docker-compose.yml
- Redis: Modify command parameters
- Qdrant: Adjust environment variables
- Traefik: Update command configuration

## Production Deployment

### Security Checklist
- [ ] Change all default passwords
- [ ] Update API keys
- [ ] Configure proper SSL
- [ ] Set up firewall rules
- [ ] Enable monitoring
- [ ] Configure backups

### Performance Tuning
- [ ] Adjust resource limits
- [ ] Configure proper storage
- [ ] Set up monitoring
- [ ] Optimize network settings

## Contact

- **Email**: hi@binarydev.co.id
- **Website**: https://binarydev.co.id
- **Address**: Jl. Sukakarya, Pekanbaru 28293
- **Phone**: 085265279959

## License

This project is licensed under the MIT License - see the LICENSE file for details.
