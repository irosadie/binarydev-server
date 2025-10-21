#!/bin/bash
# MongoDB Entrypoint Wrapper
# Auto-fix keyfile permissions before starting MongoDB

set -e

echo "🔧 MongoDB Startup - Fixing permissions..."

# Fix keyfile permissions (must be 400 and owned by mongodb user)
if [ -f /data/keyfile/mongodb-keyfile ]; then
    echo "📝 Setting keyfile permissions..."
    chown mongodb:mongodb /data/keyfile/mongodb-keyfile
    chmod 400 /data/keyfile/mongodb-keyfile
    echo "✅ KeyFile permissions fixed"
else
    echo "⚠️ KeyFile not found at /data/keyfile/mongodb-keyfile"
fi

# Fix data directory permissions
echo "📁 Setting data directory permissions..."
chown -R mongodb:mongodb /data/db
echo "✅ Data directory permissions fixed"

# Start MongoDB with original entrypoint
echo "🚀 Starting MongoDB..."
exec docker-entrypoint.sh "$@"
