#!/bin/bash

# BinaryDev Database Backup Script
# Usage: ./scripts/backup-databases.sh [all|postgresql|mongodb|redis]

echo "🛡️ BinaryDev Database Backup Tool..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    source .env
else
    print_error ".env file not found!"
    exit 1
fi

# Create backup directory with timestamp
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"

print_status "Backup directory: ${BACKUP_DIR}"

# Function to backup PostgreSQL
backup_postgresql() {
    print_status "Backing up PostgreSQL..."
    if docker exec postgresql pg_isready -U ${POSTGRES_USER} >/dev/null 2>&1; then
        docker exec postgresql pg_dumpall -U ${POSTGRES_USER} > "${BACKUP_DIR}/postgresql_full_backup.sql"
        docker exec postgresql pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > "${BACKUP_DIR}/postgresql_${POSTGRES_DB}_backup.sql"
        print_success "PostgreSQL backup completed"
        
        # Compress backup
        gzip "${BACKUP_DIR}/postgresql_full_backup.sql"
        gzip "${BACKUP_DIR}/postgresql_${POSTGRES_DB}_backup.sql"
        print_success "PostgreSQL backups compressed"
    else
        print_error "PostgreSQL is not ready for backup"
        return 1
    fi
}

# Function to backup MongoDB
backup_mongodb() {
    print_status "Backing up MongoDB..."
    if docker exec mongodb mongosh --quiet --eval "db.runCommand('ping').ok" >/dev/null 2>&1; then
        docker exec mongodb mongodump --db ${MONGO_INITDB_DATABASE} --out "/data/backup_temp"
        docker cp mongodb:/data/backup_temp "${BACKUP_DIR}/mongodb_backup"
        docker exec mongodb rm -rf "/data/backup_temp"
        
        # Compress backup
        tar -czf "${BACKUP_DIR}/mongodb_${MONGO_INITDB_DATABASE}_backup.tar.gz" -C "${BACKUP_DIR}" mongodb_backup
        rm -rf "${BACKUP_DIR}/mongodb_backup"
        
        print_success "MongoDB backup completed and compressed"
    else
        print_error "MongoDB is not ready for backup"
        return 1
    fi
}

# Function to backup Redis
backup_redis() {
    print_status "Backing up Redis..."
    if docker exec redis redis-cli -a ${REDIS_PASSWORD} ping >/dev/null 2>&1; then
        # Force Redis to save current state
        docker exec redis redis-cli -a ${REDIS_PASSWORD} BGSAVE
        sleep 5  # Wait for background save to complete
        
        # Copy the dump file
        docker cp redis:/data/dump.rdb "${BACKUP_DIR}/redis_dump.rdb"
        
        # Compress backup
        gzip "${BACKUP_DIR}/redis_dump.rdb"
        
        print_success "Redis backup completed and compressed"
    else
        print_error "Redis is not ready for backup"
        return 1
    fi
}

# Function to create backup info file
create_backup_info() {
    cat > "${BACKUP_DIR}/backup_info.txt" << EOF
BinaryDev Database Backup
========================
Date: $(date)
Environment: ${NETWORK_NAME}

Services Backed Up:
- PostgreSQL Database: ${POSTGRES_DB}
- MongoDB Database: ${MONGO_INITDB_DATABASE}
- Redis Data

Backup Files:
$(ls -la ${BACKUP_DIR}/)

Restore Commands:
================

PostgreSQL:
- Full restore: zcat postgresql_full_backup.sql.gz | docker exec -i postgresql psql -U ${POSTGRES_USER}
- Database restore: zcat postgresql_${POSTGRES_DB}_backup.sql.gz | docker exec -i postgresql psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}

MongoDB:
- Extract: tar -xzf mongodb_${MONGO_INITDB_DATABASE}_backup.tar.gz
- Restore: docker cp mongodb_backup mongodb:/data/restore_temp && docker exec mongodb mongorestore --db ${MONGO_INITDB_DATABASE} /data/restore_temp/${MONGO_INITDB_DATABASE}

Redis:
- Stop Redis: docker-compose stop redis
- Extract: zcat redis_dump.rdb.gz > dump.rdb
- Copy: docker cp dump.rdb redis:/data/dump.rdb
- Start Redis: docker-compose start redis
EOF
}

# Main backup logic
case "${1:-all}" in
    "postgresql")
        backup_postgresql
        ;;
    "mongodb")
        backup_mongodb
        ;;
    "redis")
        backup_redis
        ;;
    "all")
        backup_postgresql
        backup_mongodb
        backup_redis
        ;;
    *)
        print_error "Usage: $0 [all|postgresql|mongodb|redis]"
        exit 1
        ;;
esac

# Create info file
create_backup_info

# Show summary
echo ""
print_success "Backup completed successfully!"
print_status "Backup location: ${BACKUP_DIR}"
print_status "Backup size: $(du -sh ${BACKUP_DIR} | cut -f1)"
echo ""
print_status "Files created:"
ls -la "${BACKUP_DIR}/"
echo ""
print_warning "Store backups securely and test restore procedures regularly!"
