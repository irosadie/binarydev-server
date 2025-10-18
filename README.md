# BinaryDev Server Infrastructure

Production-ready Docker infrastructure stack untuk development dan production dengan PostgreSQL, MongoDB, Redis, Qdrant Vector Database, dan Traefik reverse proxy.

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- macOS (development) / Ubuntu Server (production)
- Minimum 4GB RAM, 20GB disk space

### Development Setup

```bash
# 1. Clone repository
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server

# 2. Copy environment file
cp .env.example .env

# 3. Start all services
make start
```

### Production Setup

```bash
# 1. Clone repository
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server

# 2. Configure environment
cp .env.example .env
# Edit .env dengan konfigurasi production yang aman

# 3. Setup firewall (Ubuntu)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5432/tcp  # PostgreSQL (jika perlu remote access)
sudo ufw allow 27017/tcp # MongoDB (jika perlu remote access)

# 4. Start services
make start
```

## 📋 Services Overview

| Service    | Port | Description                    | Health Check |
|------------|------|--------------------------------|--------------|
| PostgreSQL | 5432 | Primary relational database    | ✅ Healthy   |
| MongoDB    | 27017| NoSQL document database        | ✅ Healthy   |
| Redis      | 6379 | In-memory cache & session store| ✅ Healthy   |
| BullMQ Board | 3001 | Queue monitoring dashboard   | ✅ Healthy   |
| Qdrant     | 6333 | Vector database for AI/ML      | ⚠️ API Key   |
| Traefik    | 8080 | Reverse proxy & load balancer  | ⚠️ Config    |

## 🔧 Configuration

### Environment Variables (.env)

```bash
# Network
NETWORK_NAME=binarydev
SSL_EMAIL=admin@yourdomain.com

# PostgreSQL - Production Database
POSTGRES_DB=binarydb
POSTGRES_USER=binarydev
POSTGRES_PASSWORD=CHANGE_THIS_SECURE_PASSWORD
POSTGRES_PORT=5432

# MongoDB - Document Database
MONGO_INITDB_ROOT_USERNAME=binarydev
MONGO_INITDB_ROOT_PASSWORD=CHANGE_THIS_SECURE_PASSWORD
MONGO_INITDB_DATABASE=binarydb
MONGO_DB_PORT=27017

# Redis - Cache & Sessions
REDIS_PASSWORD=CHANGE_THIS_SECURE_PASSWORD
REDIS_PORT=6379

# BullMQ Board - Queue Monitoring
BULLMQ_BOARD_PORT=3001

# Qdrant - Vector Database
QDRANT_PORT=6333
QDRANT_API_KEY=CHANGE_THIS_API_KEY
```

### Database Credentials

**PostgreSQL (Production Ready)**
- Host: `localhost` atau `your-server-ip`
- Port: `5432`
- Database: `binarydb`
- Username: `binarydev`
- Password: Sesuai .env

**MongoDB (Document Store)**
- Host: `localhost` atau `your-server-ip`
- Port: `27017`
- Database: `binarydb`
- Username: `binarydev`
- Password: Sesuai .env

**Redis (Cache)**
- Host: `localhost` atau `your-server-ip`
- Port: `6379`
- Password: Sesuai .env

**Qdrant (Vector DB)**
- Host: `localhost` atau `your-server-ip`
- Port: `6333`
- API Key: Sesuai .env

**BullMQ Board (Queue Monitoring)**
- URL Local: `http://localhost:3001`
- URL Production: `https://bullmq.yourdomain.com`
- Monitoring: Real-time queue status, jobs, and workers

## 🛠️ Management Commands

```bash
# Start all services
make start

# Stop all services
make down

# View logs
make logs
make logs-postgresql
make logs-mongodb
make logs-bullmq

# Check status
make status

# BullMQ specific
make bullmq-ui          # Open BullMQ dashboard
make restart-bullmq     # Restart BullMQ service

# Clean restart (removes all data)
make down-clean
make start
```

## 🔍 Health Checks & Monitoring

### Built-in Health Checks

Semua services memiliki health checks built-in:

```bash
# Check service status
docker-compose ps

# Test database connections
docker exec postgresql psql -U binarydev -d binarydb -c "SELECT version();"
docker exec mongodb mongosh --quiet --eval "db.runCommand('ping').ok"
docker exec redis redis-cli -a $REDIS_PASSWORD ping
```

### Manual Testing

```bash
# PostgreSQL
psql -h localhost -U binarydev -d binarydb

# MongoDB
mongosh mongodb://binarydev:password@localhost:27017/binarydb?authSource=admin

# Redis
redis-cli -h localhost -p 6379 -a password

# Qdrant
**Qdrant**
curl -H "api-key: your_api_key" http://localhost:6333/health
```

## 📦 BullMQ Queue Management

### Overview
BullMQ adalah powerful queue library untuk Node.js yang menggunakan Redis sebagai backend. Service `bullmq-board` menyediakan web UI untuk monitoring dan management.

### Access BullMQ Board
- **Local**: http://localhost:3001
- **Production**: https://bullmq.yourdomain.com (via Traefik)
- **Quick Open**: `make bullmq-ui`

### Setup dalam Next.js/Node.js Application

```bash
# Install dependencies
npm install bullmq
# atau
yarn add bullmq
```

### Example Implementation

**1. Queue Configuration (lib/queue.ts)**
```typescript
import { Queue, Worker, QueueEvents } from 'bullmq';

const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
};

// Create Queue
export const emailQueue = new Queue('email', { connection });
export const notificationQueue = new Queue('notification', { connection });

// Add Job
export async function sendEmail(to: string, subject: string, body: string) {
  await emailQueue.add('send-email', {
    to,
    subject,
    body,
    timestamp: new Date().toISOString(),
  });
}
```

**2. Worker Implementation (workers/email.worker.ts)**
```typescript
import { Worker } from 'bullmq';

const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
};

const emailWorker = new Worker(
  'email',
  async (job) => {
    console.log('Processing email job:', job.id);
    const { to, subject, body } = job.data;
    
    // Your email sending logic here
    await sendEmailViaProvider(to, subject, body);
    
    return { success: true, sentAt: new Date().toISOString() };
  },
  { connection }
);

emailWorker.on('completed', (job) => {
  console.log(`Job ${job.id} completed successfully`);
});

emailWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed with error:`, err);
});
```

**3. Queue Events (for monitoring)**
```typescript
import { QueueEvents } from 'bullmq';

const queueEvents = new QueueEvents('email', { connection });

queueEvents.on('completed', ({ jobId }) => {
  console.log(`Email job ${jobId} completed`);
});

queueEvents.on('failed', ({ jobId, failedReason }) => {
  console.log(`Email job ${jobId} failed:`, failedReason);
});
```

**4. API Route Example (Next.js)**
```typescript
// app/api/send-email/route.ts
import { sendEmail } from '@/lib/queue';

export async function POST(request: Request) {
  const { to, subject, body } = await request.json();
  
  try {
    await sendEmail(to, subject, body);
    return Response.json({ 
      success: true, 
      message: 'Email queued successfully' 
    });
  } catch (error) {
    return Response.json({ 
      success: false, 
      error: 'Failed to queue email' 
    }, { status: 500 });
  }
}
```

### BullMQ Board Features

- 📊 **Real-time Monitoring**: View active, completed, failed jobs
- 🔄 **Job Management**: Retry, remove, or pause jobs
- 📈 **Statistics**: Queue metrics and performance data
- 🔍 **Job Details**: Inspect job data and logs
- ⚡ **Multiple Queues**: Monitor all queues in one dashboard

### Common Use Cases

1. **Email Sending**: Queue email deliveries
2. **Image Processing**: Resize, compress images
3. **Data Export**: Generate reports asynchronously
4. **Notifications**: Send push notifications
5. **Scheduled Tasks**: Run periodic jobs
6. **Webhook Processing**: Handle webhook payloads

### Monitoring & Debugging

```bash
# View BullMQ logs
make logs-bullmq

# Restart if needed
make restart-bullmq

# Check Redis connection
docker exec redis redis-cli -a [password] ping
```

## 🔒 Security Features
```

## 🔒 Security Features

### Production Security

1. **Password Protection**: Semua databases memiliki authentication
2. **Network Isolation**: Services dalam isolated Docker network
3. **Configuration Security**: Sensitive data dalam .env file
4. **File Permissions**: Proper permissions untuk config files
5. **Remote Access Control**: pg_hba.conf dikonfigurasi untuk remote access

### Remote Database Access

**PostgreSQL Remote Access:**
```bash
# Connection string
postgresql://binarydev:password@your-server-ip:5432/binarydb

# pgAdmin/DBeaver configuration
Host: your-server-ip
Port: 5432
Database: binarydb
Username: binarydev
Password: your-password
```

**MongoDB Remote Access:**
```bash
# Connection string
mongodb://binarydev:password@your-server-ip:27017/binarydb

# MongoDB Compass configuration
Host: your-server-ip
Port: 27017
Authentication: Username/Password
Username: binarydev
Password: your-password
Database: binarydb
```

## 📂 Directory Structure

```
binary-server/
├── config/
│   ├── mongodb/            # MongoDB configuration
│   │   └── mongodb-keyfile # Replica set key (if needed)
│   └── postgresql/         # PostgreSQL configuration
│       ├── init.sql        # Database initialization
│       ├── pg_hba.conf     # Access control
│       └── postgresql.conf # Server configuration
├── data/                   # Persistent data (auto-created)
│   ├── mongodb/
│   ├── postgresql/
│   ├── redis/
│   ├── qdrant/
│   └── traefik/
├── logs/                   # Service logs (auto-created)
│   ├── mongodb/
│   └── traefik/
├── scripts/
│   └── start-services.sh   # Enhanced startup script
├── docker-compose.yml      # Main orchestration file
├── Makefile               # Management commands
└── .env                   # Environment configuration
```

## 🚨 Troubleshooting

### Common Issues

**PostgreSQL Connection Issues:**
```bash
# Check logs
make logs-postgresql

# Test connection
docker exec postgresql pg_isready -U binarydev -d binarydb

# Reset if needed
make down
rm -rf data/postgresql/*
make start
```

**MongoDB Connection Issues:**
```bash
# Check logs
docker logs mongodb

# Test connection
docker exec mongodb mongosh --quiet --eval "db.runCommand('ping').ok"
```

**Network Issues:**
```bash
# Check Docker network
docker network ls
docker network inspect binarydev

# Recreate network
make down
docker network rm binarydev
make start
```

### Performance Optimization

**PostgreSQL Tuning:**
- shared_buffers: 25% of RAM
- effective_cache_size: 75% of RAM
- work_mem: 4MB (default sudah optimized)

**MongoDB Tuning:**
- Gunakan replica set untuk production
- Enable sharding untuk data besar

**Redis Tuning:**
- Persistent storage dengan AOF enabled
- Memory management sudah dikonfigurasi

## 🔄 Backup & Recovery

### Database Backups

**PostgreSQL:**
```bash
# Backup
docker exec postgresql pg_dump -U binarydev binarydb > backup.sql

# Restore
cat backup.sql | docker exec -i postgresql psql -U binarydev -d binarydb
```

**MongoDB:**
```bash
# Backup
docker exec mongodb mongodump --db binarydb --out /data/backup

# Restore
docker exec mongodb mongorestore --db binarydb /data/backup/binarydb
```

## 📈 Production Deployment

### Ubuntu Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin

# Clone and setup
git clone https://github.com/irosadie/binarydev-server.git
cd binarydev-server
cp .env.example .env

# Edit .env untuk production
nano .env

# Start services
make start
```

### SSL/TLS dengan Traefik

Traefik sudah dikonfigurasi untuk automatic SSL certificates dengan Let's Encrypt:

1. Update `.env` dengan email valid untuk SSL
2. Pastikan domain pointing ke server IP
3. Traefik akan automatic generate SSL certificates

## 📝 Changelog

### v1.0.0 (Current)
- ✅ PostgreSQL 16 dengan remote access
- ✅ MongoDB 7 standalone (production ready)
- ✅ Redis 7 dengan persistence
- ✅ Qdrant vector database
- ✅ Traefik v3.0 reverse proxy
- ✅ Comprehensive health checks
- ✅ Production-ready security
- ✅ Cross-platform compatibility (macOS/Linux)

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📞 Support

- GitHub Issues: [Create Issue](https://github.com/irosadie/binarydev-server/issues)
- Email: support@binarydev.co.id

---

**BinaryDev Server Infrastructure** - Production-ready, secure, dan scalable database stack untuk modern applications.

#### Recommended (with auto-fix):
```bash
# Start with automatic PostgreSQL fixes
make start
```

#### Simple start:
```bash
# Start all services (basic)
make up

# Check status
make status
```

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

### 🐘 PostgreSQL
- **Port**: 5432
- **Features**: Full SQL database, remote access support
- **Authentication**: Username/password dari .env
- **Remote Access**: Dapat diakses dari pgAdmin client external

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
make logs-mongodb    # MongoDB logs
make logs-redis      # Redis logs
make logs-qdrant     # Qdrant logs
make logs-postgresql # PostgreSQL logs
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

## PostgreSQL Database

### Connection Details
- **Host**: localhost (atau IP server)
- **Port**: 5432 (default, dapat diubah di .env)
- **Database**: binarydb (sesuai POSTGRES_DB di .env)
- **Username**: binarydev (sesuai POSTGRES_USER di .env)
- **Password**: 5ayagantenG (sesuai POSTGRES_PASSWORD di .env)

### Connecting with pgAdmin
1. Buka pgAdmin di client
2. Add New Server:
   - **Name**: BinaryDev PostgreSQL
   - **Host**: IP address server (atau localhost jika lokal)
   - **Port**: 5432
   - **Username**: binarydev
   - **Password**: 5ayagantenG
   - **Database**: binarydb

### Command Line Access
```bash
# Connect via psql (dari dalam container)
docker exec -it postgresql psql -U binarydev -d binarydb

# Connect via psql (dari host jika psql terinstall)
psql -h localhost -p 5432 -U binarydev -d binarydb
```

### Database Operations
```sql
-- Create table example
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert data
INSERT INTO users (username, email) VALUES ('johndoe', 'john@example.com');

-- Query data
SELECT * FROM users;
```

### Backup & Restore
```bash
# Backup database
docker exec postgresql pg_dump -U binarydev binarydb > backup.sql

# Restore database
docker exec -i postgresql psql -U binarydev binarydb < backup.sql
```

## Directory Structure
```
├── data/
│   ├── mongodb/     # MongoDB data
│   ├── redis/       # Redis data
│   ├── qdrant/      # Qdrant storage
│   └── postgresql/  # PostgreSQL data
├── logs/            # Service logs
│   └── postgresql/  # PostgreSQL logs
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

### PostgreSQL
- ✅ Username/password authentication
- ✅ Network isolation
- ✅ Remote access support
- ✅ Query logging enabled

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
make logs              # All services
make logs-qdrant       # Qdrant only
make logs-mongodb      # MongoDB only
make logs-redis        # Redis only
make logs-postgresql   # PostgreSQL only
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
