# MongoDB Replica Set Setup

## Konfigurasi Otomatis

MongoDB sudah dikonfigurasi dengan:
- ✅ Authentication enabled (username/password)
- ✅ Single-node replica set (support transactions untuk Prisma)
- ✅ Auto-initialization via script
- ✅ KeyFile security untuk replica set

## Local Development

### 1. Setup
```bash
# Clone repo
git clone <repo>
cd binary-server

# Copy .env.example ke .env (sudah ada default values)
cp .env.example .env

# Pastikan MONGO_REPLICA_HOST di .env:
MONGO_REPLICA_HOST=localhost:27017
```

### 2. Start Services
```bash
# Buat network (sekali aja)
docker network create binarydev

# Start semua service (otomatis init replica set!)
make start
```

### 3. Connection String untuk Prisma
```bash
mongodb://binarydev:B1n4ryd3vc01d@localhost:27017/binarydb?replicaSet=rs0&directConnection=true&authSource=admin
```

## Production Deployment

### 1. Di Server

```bash
# Clone repo
git clone <repo>
cd binary-server

# Copy dan edit .env
cp .env.example .env
nano .env
```

### 2. Edit MONGO_REPLICA_HOST di .env

**PENTING**: Ganti dengan IP public server kamu!

```bash
# Contoh:
MONGO_REPLICA_HOST=43.163.118.150:27017
```

### 3. Buka Firewall

```bash
# Untuk Ubuntu
sudo ufw allow 27017/tcp

# Atau di cloud provider (AWS, GCP, DigitalOcean)
# Buka port 27017 di Security Group / Firewall rules
```

### 4. Start Services

```bash
# Buat network
docker network create binarydev

# Start (otomatis init replica set dengan IP public!)
make start
```

### 5. Connection String dari Luar

Dari aplikasi external (laptop, server lain, etc):

```bash
mongodb://binarydev:B1n4ryd3vc01d@43.163.118.150:27017/binarydb?replicaSet=rs0&directConnection=true&authSource=admin
```

## Troubleshooting

### MongoDB Restarting Loop

Jika MongoDB restart terus di server:

```bash
# Check logs
docker logs mongodb

# Biasanya masalah keyFile permission. Re-generate:
openssl rand -base64 756 > config/mongodb/keyfile
chmod 400 config/mongodb/keyfile

# Restart
docker-compose restart mongodb
```

### Replica Set Belum Initialized

```bash
# Check status
make mongodb-status

# Manual init (kalau perlu)
make mongodb-init
```

### Tidak Bisa Connect dari Luar

1. **Check firewall**:
   ```bash
   sudo ufw status
   sudo ufw allow 27017/tcp
   ```

2. **Check MongoDB listening**:
   ```bash
   docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d --authenticationDatabase admin --eval "db.adminCommand({ connectionStatus: 1 })"
   ```

3. **Check replica set host config**:
   ```bash
   docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d --authenticationDatabase admin --eval "rs.conf().members"
   ```

   Harus sesuai dengan IP public server, bukan `localhost` atau `mongodb`.

4. **Reconfig replica set** (kalau salah):
   ```bash
   docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d --authenticationDatabase admin --eval "cfg=rs.conf(); cfg.members[0].host='YOUR_SERVER_IP:27017'; rs.reconfig(cfg, {force:true})"
   ```

## Useful Commands

```bash
# Status replica set
make mongodb-status

# Init/re-init replica set
make mongodb-init

# Logs
make logs-mongodb

# Restart MongoDB only
docker-compose restart mongodb

# Full restart
make down
make start
```

## Security Notes

### Production Checklist

- [ ] Ganti default password di `.env`
- [ ] Generate keyFile baru: `openssl rand -base64 756 > config/mongodb/keyfile && chmod 400 config/mongodb/keyfile`
- [ ] Setup firewall rules (allow hanya IP yang diperlukan)
- [ ] Enable SSL/TLS untuk production (opsional tapi recommended)
- [ ] Backup rutin database

### Change Password

1. Edit `.env`:
   ```bash
   MONGO_INITDB_ROOT_PASSWORD=your_new_strong_password
   ```

2. Recreate container:
   ```bash
   docker-compose down
   docker volume rm binary-server_mongodb_data
   make start
   ```

3. Update connection string di aplikasi.
