#!/bin/bash
# MongoDB Fully Automated Entrypoint
# Zero manual intervention - auto-initialize replica set on first start

set -e

echo "🔧 MongoDB Auto-Setup - Zero Manual Intervention..."

# Fix keyfile permissions (must be 400 and owned by mongodb user)
if [ -f /data/keyfile/mongodb-keyfile ]; then
    echo "� Fixing keyfile permissions..."
    chown mongodb:mongodb /data/keyfile/mongodb-keyfile
    chmod 400 /data/keyfile/mongodb-keyfile
    echo "✅ KeyFile permissions fixed"
fi

# Fix data directory ownership
echo "📁 Fixing data directory ownership..."
chown -R mongodb:mongodb /data/db /data/configdb
echo "✅ Data directory ownership fixed"

# Start MongoDB in background as mongodb user
echo "🚀 Starting MongoDB..."
gosu mongodb mongod --replSet "${MONGO_REPLICA_SET_NAME:-rs0}" --bind_ip_all --keyFile /data/keyfile/mongodb-keyfile &
MONGO_PID=$!

# Wait for MongoDB to be ready (without authentication initially)
echo "⏳ Waiting for MongoDB to be ready..."
for i in {1..30}; do
    if mongosh --quiet --eval "db.runCommand('ping').ok" >/dev/null 2>&1; then
        echo "✅ MongoDB is ready!"
        break
    fi
    echo -n "."
    sleep 2
done

# Auto-initialize replica set if not already initialized
echo "� Checking replica set status..."
RS_STATUS=$(mongosh --quiet --eval "try { rs.status().ok } catch(e) { 0 }" 2>/dev/null || echo "0")

if [ "$RS_STATUS" = "0" ]; then
    echo "🎯 Initializing replica set automatically..."
    
    mongosh --quiet --eval "
        rs.initiate({
            _id: '${MONGO_REPLICA_SET_NAME:-rs0}',
            members: [
                { _id: 0, host: 'mongodb:27017' }
            ]
        })
    " >/dev/null 2>&1
    
    echo "⏳ Waiting for replica set to be PRIMARY..."
    sleep 10
    
    # Create root user if credentials provided
    if [ ! -z "$MONGO_INITDB_ROOT_USERNAME" ] && [ ! -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
        echo "👤 Creating admin user..."
        mongosh admin --quiet --eval "
            try {
                db.createUser({
                    user: '$MONGO_INITDB_ROOT_USERNAME',
                    pwd: '$MONGO_INITDB_ROOT_PASSWORD',
                    roles: ['root']
                })
                print('✅ Admin user created')
            } catch(e) {
                print('ℹ️ User already exists')
            }
        " 2>/dev/null
    fi
    
    # Create initial database if specified
    if [ ! -z "$MONGO_INITDB_DATABASE" ] && [ ! -z "$MONGO_INITDB_ROOT_USERNAME" ]; then
        echo "📦 Creating initial database..."
        mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --quiet --eval "
            use $MONGO_INITDB_DATABASE
            db.init.insertOne({initialized: new Date(), message: 'Database created automatically'})
            print('✅ Database $MONGO_INITDB_DATABASE created')
        " 2>/dev/null
    fi
    
    echo "✅ Replica set initialized successfully!"
    echo "🎉 MongoDB is ready for connections!"
else
    echo "✅ Replica set already initialized"
fi

echo "📊 Replica Set Status:"
mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --quiet --eval "rs.status().members.forEach(m => print('  - ' + m.name + ': ' + m.stateStr))" 2>/dev/null || echo "  Waiting for authentication to be ready..."

echo ""
echo "� Connection String:"
echo "   mongodb://$MONGO_INITDB_ROOT_USERNAME:****@mongodb:27017/$MONGO_INITDB_DATABASE?replicaSet=${MONGO_REPLICA_SET_NAME:-rs0}&authSource=admin"
echo ""
echo "✅ MongoDB fully operational!"

# Keep MongoDB running in foreground
wait $MONGO_PID
