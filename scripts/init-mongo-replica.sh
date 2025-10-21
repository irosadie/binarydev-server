#!/bin/bash

# MongoDB Replica Set Auto-Initialization Script
# This script checks if MongoDB replica set is initialized and initializes it if needed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[MONGO-INIT]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[MONGO-INIT]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[MONGO-INIT]${NC} $1"
}

print_error() {
    echo -e "${RED}[MONGO-INIT]${NC} $1"
}

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

REPLICA_SET_NAME=${MONGO_REPLICA_SET_NAME:-rs0}
MONGO_USER=${MONGO_INITDB_ROOT_USERNAME:-root}
MONGO_PASS=${MONGO_INITDB_ROOT_PASSWORD:-password}
REPLICA_HOST=${MONGO_REPLICA_HOST:-mongodb:27017}
MAX_RETRIES=30
RETRY_INTERVAL=2

print_status "Waiting for MongoDB to be ready..."

# Wait for MongoDB to be accessible
for i in $(seq 1 $MAX_RETRIES); do
    if docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "db.adminCommand({ ping: 1 })" >/dev/null 2>&1; then
        print_success "MongoDB is ready"
        break
    fi
    
    if [ $i -eq $MAX_RETRIES ]; then
        print_error "MongoDB failed to start after ${MAX_RETRIES} retries"
        exit 1
    fi
    
    print_status "Waiting for MongoDB... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

# Check if replica set is already initialized
print_status "Checking replica set status..."
if docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "rs.status()" >/dev/null 2>&1; then
    RS_NAME=$(docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "rs.status().set" 2>/dev/null || echo "")
    if [ -n "$RS_NAME" ]; then
        print_success "Replica set '$RS_NAME' is already initialized"
        
        # Verify it's the correct replica set name
        if [ "$RS_NAME" != "$REPLICA_SET_NAME" ]; then
            print_warning "Replica set name mismatch: expected '$REPLICA_SET_NAME', got '$RS_NAME'"
        fi
        
        # Show replica set members
        print_status "Current replica set configuration:"
        docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "rs.conf().members.forEach(m => print('  Member ' + m._id + ': ' + m.host))"
        exit 0
    fi
fi

# Replica set not initialized, initialize it now
print_status "Replica set not initialized. Initializing replica set '$REPLICA_SET_NAME'..."

INIT_RESULT=$(docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "
try {
    rs.initiate({
        _id: '$REPLICA_SET_NAME',
        members: [
            { _id: 0, host: '$REPLICA_HOST' }
        ]
    });
} catch (e) {
    print('Error: ' + e);
    quit(1);
}
" 2>&1)

if echo "$INIT_RESULT" | grep -q '"ok".*1\|"ok": 1'; then
    print_success "Replica set '$REPLICA_SET_NAME' initialized successfully"
    
    # Wait for replica set to stabilize
    print_status "Waiting for replica set to become PRIMARY..."
    for i in $(seq 1 15); do
        STATE=$(docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "rs.status().myState" 2>/dev/null || echo "0")
        if [ "$STATE" = "1" ]; then
            print_success "Replica set is now PRIMARY and ready"
            break
        fi
        sleep 1
    done
    
    # Show final status
    print_status "Final replica set configuration:"
    docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet --eval "
        var status = rs.status();
        print('Replica Set: ' + status.set);
        print('State: ' + (status.myState === 1 ? 'PRIMARY' : 'SECONDARY/OTHER'));
        status.members.forEach(function(m) {
            print('  Member ' + m._id + ': ' + m.name + ' (' + m.stateStr + ')');
        });
    "
else
    print_error "Failed to initialize replica set"
    print_error "Output: $INIT_RESULT"
    exit 1
fi

print_success "MongoDB replica set initialization complete!"
print_status "Connection string for apps: mongodb://$MONGO_USER:$MONGO_PASS@mongodb:27017/YOUR_DB?replicaSet=$REPLICA_SET_NAME&authSource=admin"
print_status "Connection string for host: mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/YOUR_DB?replicaSet=$REPLICA_SET_NAME&directConnection=true&authSource=admin"
