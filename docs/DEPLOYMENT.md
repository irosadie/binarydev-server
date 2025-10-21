# 🚀 Quick Server Deployment Guide

Panduan deploy BinaryDev Server Infrastructure ke server baru **tanpa setup manual**.

## ✅ Portable & Zero-Configuration

Setup ini **100% portable** - tinggal clone dan run, tidak perlu:
- ❌ Manual `chown` file permissions
- ❌ Manual keyfile setup
- ❌ User/group configuration
- ❌ Manual directory permissions

Semua **otomatis** di handle oleh Docker entrypoint!

## 📦 What's Included

| Service | Port | Auto-Config |
|---------|------|-------------|
| MongoDB Replica Set | 27017 | ✅ KeyFile permissions auto-fixed |
| PostgreSQL | 5432 | ✅ Ready to use |
| Redis | 6379 | ✅ Ready to use |
| RabbitMQ | 5672, 15672 | ✅ Ready to use |
| BullMQ Board | 3001 | ✅ Ready to use |
| Qdrant | 6333 | ✅ Ready to use |
| Traefik | 80, 443, 8080 | ✅ Ready to use |

## 🎯 Deployment Steps

### 1. Clone Repository
```bash
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server
```

### 2. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit passwords and domain
```

**Important Environment Variables:**
```bash
DOMAIN=yourdomain.com
SSL_EMAIL=your-email@domain.com

# Change ALL passwords!
MONGO_INITDB_ROOT_PASSWORD=your_secure_password
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_secure_password
RABBITMQ_PASSWORD=your_secure_password
QDRANT_API_KEY=your_secure_api_key
```

### 3. Start Services
```bash
# Create Docker network
make create-network

# Start all services (auto-fix permissions)
make start

# Or use docker-compose directly
docker-compose up -d
```

### 4. Initialize MongoDB Replica Set
```bash
# Wait 30-60 seconds for MongoDB to be healthy
docker-compose ps mongodb

# Initialize replica set
make mongodb-init-replica
```

### 5. Verify All Services
```bash
# Check status
make status

# All should show: Up (healthy)
docker-compose ps
```

## 🔧 Automatic Permission Fixes

MongoDB menggunakan **custom entrypoint wrapper** yang otomatis fix:

1. **KeyFile Permissions**
   - Auto `chown mongodb:mongodb`
   - Auto `chmod 400`
   
2. **Data Directory**
   - Auto `chown -R mongodb:mongodb /data/db`

3. **Zero Manual Configuration**
   - Tidak perlu SSH dan run manual commands
   - Tidak perlu worry tentang uid/gid

## 🔄 Moving to New Server

**Cara 1: Fresh Install**
```bash
# On new server
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server
cp .env.example .env
# Edit .env with your settings
make create-network
make start
make mongodb-init-replica
```

**Cara 2: Backup & Restore**
```bash
# On old server - backup data
make backup

# Transfer backup to new server
scp -r backups/ user@new-server:/path/to/binarydev-server/

# On new server - restore
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server
cp .env.example .env
# Copy backup data
cp -r backups/latest/* data/
make create-network
make start
```

## 🌐 Server Requirements

### Minimum Specs
- **OS**: Ubuntu 20.04+ / Debian 11+
- **RAM**: 4GB (8GB recommended)
- **Disk**: 20GB free space
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

### Install Docker (Ubuntu)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verify
docker --version
docker compose version
```

### Firewall Setup
```bash
# Allow necessary ports
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Database ports (if need remote access)
sudo ufw allow 5432/tcp   # PostgreSQL
sudo ufw allow 27017/tcp  # MongoDB
sudo ufw allow 5672/tcp   # RabbitMQ
sudo ufw allow 6379/tcp   # Redis

# Enable firewall
sudo ufw enable
```

## 🔐 Security Checklist

Before deploying to production:

- [ ] Change all default passwords in `.env`
- [ ] Set proper `DOMAIN` and `SSL_EMAIL`
- [ ] Enable firewall and restrict database ports
- [ ] Use strong passwords (20+ characters, mixed case, numbers, symbols)
- [ ] Setup SSH key authentication (disable password login)
- [ ] Setup automated backups
- [ ] Enable Docker log rotation
- [ ] Setup monitoring (optional)

## 📊 Health Checks

```bash
# Quick status check
make status

# Individual service logs
make logs-mongodb
make logs-postgresql
make logs-rabbitmq
make logs-redis

# Check MongoDB replica set
make mongodb-status
```

## 🆘 Troubleshooting

### MongoDB Restart Loop
**FIXED**: Auto-fixed by entrypoint wrapper. No manual action needed.

### Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :27017

# Stop conflicting service
sudo systemctl stop mongodb  # if system MongoDB running
```

### Network Already Exists Error
```bash
# Network is external, just needs to exist
make create-network
```

### Permission Denied Errors
```bash
# All permissions auto-fixed by Docker
# Just restart the service
docker-compose restart mongodb
```

## 🎓 Common Commands

```bash
# Start all services
make start

# Stop all services
make down

# Restart specific service
docker-compose restart mongodb

# View logs
make logs
make logs-mongodb

# Backup databases
make backup

# Check status
make status

# MongoDB replica set management
make mongodb-init-replica
make mongodb-status
make mongodb-shell
```

## 📈 Scaling for Production

### Multi-Node MongoDB Replica Set

Edit `docker-compose.yml` to add secondary nodes:

```yaml
mongodb-secondary-1:
  image: mongo:7
  hostname: mongodb-secondary-1
  # ... same config as primary
  ports:
    - "27018:27017"

mongodb-secondary-2:
  image: mongo:7
  hostname: mongodb-secondary-2
  # ... same config as primary
  ports:
    - "27019:27017"
```

Then initialize with 3 members:
```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb:27017", priority: 2 },
    { _id: 1, host: "mongodb-secondary-1:27017" },
    { _id: 2, host: "mongodb-secondary-2:27017" }
  ]
});
```

## 🔗 Connection Strings

### MongoDB
```
mongodb://binarydev:password@your-server-ip:27017/binarydb?replicaSet=rs0&authSource=admin
```

### PostgreSQL
```
postgresql://binarydev:password@your-server-ip:5432/binarydb
```

### Redis
```
redis://:password@your-server-ip:6379
```

### RabbitMQ
```
amqp://binarydev:password@your-server-ip:5672/binarydev
```

## 📚 Additional Resources

- [Full Documentation](README.md)
- [MongoDB Replica Set Guide](MONGODB_REPLICA_SET.md)
- [RabbitMQ Implementation](RABBITMQ_IMPLEMENTATION.md)
- [BullMQ Implementation](BULLMQ_IMPLEMENTATION.md)

## ✅ Deployment Checklist

- [ ] Clone repository
- [ ] Copy and edit `.env`
- [ ] Install Docker & Docker Compose
- [ ] Setup firewall
- [ ] Create Docker network: `make create-network`
- [ ] Start services: `make start`
- [ ] Initialize MongoDB: `make mongodb-init-replica`
- [ ] Verify all services: `make status`
- [ ] Test connections
- [ ] Setup automated backups
- [ ] Setup monitoring (optional)

---

**Deploy Time**: ~10 minutes from fresh Ubuntu server to fully running stack! 🚀

**Zero Manual Configuration**: All permissions and setup handled automatically! ✅
