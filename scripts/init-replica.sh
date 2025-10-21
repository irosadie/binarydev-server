#!/bin/bash
# MongoDB Replica Set Initialization Script
# This script initializes a single-node replica set for MongoDB

set -e

echo "🔧 Waiting for MongoDB to be ready..."
sleep 10

echo "🚀 Initializing MongoDB Replica Set: ${MONGO_REPLICA_SET_NAME:-rs0}"

# Initialize replica set
mongosh --host localhost -u "${MONGO_INITDB_ROOT_USERNAME:-binarydev}" -p "${MONGO_INITDB_ROOT_PASSWORD:-password}" --authenticationDatabase admin <<EOF
try {
  var status = rs.status();
  print("✅ Replica set already initialized");
  print(JSON.stringify(status, null, 2));
} catch (err) {
  if (err.codeName === 'NotYetInitialized') {
    print("📦 Initializing replica set...");
    
    var config = {
      _id: "${MONGO_REPLICA_SET_NAME:-rs0}",
      members: [
        {
          _id: 0,
          host: "mongodb:27017",
          priority: 1
        }
      ]
    };
    
    var result = rs.initiate(config);
    print("✅ Replica set initialized successfully");
    print(JSON.stringify(result, null, 2));
    
    // Wait for replica set to be ready
    print("⏳ Waiting for replica set to be ready...");
    var count = 0;
    while (count < 30) {
      var status = rs.status();
      if (status.members[0].stateStr === "PRIMARY") {
        print("✅ Replica set is now PRIMARY and ready!");
        break;
      }
      print("⏳ Waiting... State: " + status.members[0].stateStr);
      sleep(2000);
      count++;
    }
    
    if (count >= 30) {
      print("⚠️ Replica set initialization timeout, but continuing...");
    }
  } else {
    print("❌ Error checking replica set status:");
    print(err);
    throw err;
  }
}

// Show final status
print("📊 Final Replica Set Status:");
printjson(rs.status());
EOF

echo "✅ MongoDB Replica Set initialization completed"
