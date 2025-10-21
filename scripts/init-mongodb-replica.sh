#!/bin/bash
# Manual MongoDB Replica Set Initialization
# Run this script if automatic initialization fails

set -e

echo "🔧 MongoDB Replica Set Manual Initialization"
echo "=============================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

MONGO_USER="${MONGO_INITDB_ROOT_USERNAME:-binarydev}"
MONGO_PASS="${MONGO_INITDB_ROOT_PASSWORD:-password}"
MONGO_RS="${MONGO_REPLICA_SET_NAME:-rs0}"

echo "📊 Configuration:"
echo "  - Replica Set Name: $MONGO_RS"
echo "  - Username: $MONGO_USER"
echo "  - Host: mongodb:27017"
echo ""

echo "🔍 Checking MongoDB connection..."
if ! docker exec mongodb mongosh --quiet --eval "db.version()" > /dev/null 2>&1; then
    echo "❌ Cannot connect to MongoDB. Make sure the container is running:"
    echo "   docker-compose ps mongodb"
    exit 1
fi
echo "✅ MongoDB is accessible"
echo ""

echo "🚀 Initializing Replica Set..."
docker exec mongodb mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin <<EOF
try {
  var status = rs.status();
  print("✅ Replica set already initialized:");
  print("   State: " + status.members[0].stateStr);
  print("   Health: " + status.members[0].health);
  printjson(status);
} catch (err) {
  if (err.codeName === 'NotYetInitialized') {
    print("📦 Initializing replica set '$MONGO_RS'...");
    
    var config = {
      _id: "$MONGO_RS",
      members: [
        {
          _id: 0,
          host: "mongodb:27017",
          priority: 1
        }
      ]
    };
    
    var result = rs.initiate(config);
    if (result.ok === 1) {
      print("✅ Replica set initialized successfully!");
    } else {
      print("❌ Failed to initialize replica set:");
      printjson(result);
    }
    
    // Wait for PRIMARY state
    print("⏳ Waiting for PRIMARY state...");
    var maxAttempts = 30;
    var attempt = 0;
    
    while (attempt < maxAttempts) {
      sleep(2000);
      try {
        var status = rs.status();
        var state = status.members[0].stateStr;
        print("   Attempt " + (attempt + 1) + "/" + maxAttempts + " - State: " + state);
        
        if (state === "PRIMARY") {
          print("✅ MongoDB is now PRIMARY!");
          break;
        }
      } catch (e) {
        print("   Waiting for replica set to stabilize...");
      }
      attempt++;
    }
    
    if (attempt >= maxAttempts) {
      print("⚠️ Timeout waiting for PRIMARY state");
      print("   You may need to check the logs: docker-compose logs mongodb");
    }
  } else {
    print("❌ Unexpected error:");
    printjson(err);
  }
}

print("");
print("📊 Current Replica Set Configuration:");
try {
  printjson(rs.conf());
  print("");
  print("📊 Current Replica Set Status:");
  printjson(rs.status());
} catch (e) {
  print("⚠️ Could not retrieve replica set info");
}
EOF

echo ""
echo "✅ Initialization process completed!"
echo ""
echo "📝 Next Steps:"
echo "   1. Check replica set status: docker exec mongodb mongosh -u $MONGO_USER -p $MONGO_PASS --authenticationDatabase admin --eval 'rs.status()'"
echo "   2. Connection string: mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/binarydb?replicaSet=$MONGO_RS&authSource=admin"
echo "   3. View logs: docker-compose logs -f mongodb"
echo ""
