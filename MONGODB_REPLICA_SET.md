# MongoDB Replica Set Setup Complete ✅

MongoDB telah berhasil dikonfigurasi sebagai **Replica Set** untuk production-ready deployment.

## 🎯 What is a Replica Set?

MongoDB Replica Set adalah group of MongoDB instances yang maintain the same data set. Replica set menyediakan:

- **Redundancy**: Data replicated across multiple nodes
- **High Availability**: Automatic failover if primary fails
- **Transactions**: Multi-document ACID transactions
- **Change Streams**: Real-time data change notifications
- **Read Scalability**: Distribute reads across secondaries

## ✅ Configuration Details

### Current Setup
- **Replica Set Name**: `rs0`
- **Deployment**: Single-node (development-ready)
- **Authentication**: KeyFile-based internal authentication
- **Image**: `mongo:7` (latest stable)

### Files Modified

1. **docker-compose.yml**
   - Added `--replSet rs0` command
   - Added `--keyFile` for security
   - Mounted keyfile and init script
   - Set hostname for consistent member identification

2. **.env**
   - Added `MONGO_REPLICA_SET_NAME=rs0`

3. **config/mongodb/mongodb-keyfile**
   - Generated 756-byte random keyfile
   - Permissions set to 400 (read-only for owner)

4. **scripts/init-replica.sh**
   - Auto-initialization script (runs on first start)
   - Checks if replica set already initialized
   - Waits for PRIMARY state

5. **scripts/init-mongodb-replica.sh**
   - Manual initialization script
   - Detailed status output
   - Error handling and troubleshooting

6. **Makefile**
   - `make mongodb-init-replica` - Initialize replica set
   - `make mongodb-status` - Check replica set status
   - `make mongodb-config` - View configuration
   - `make mongodb-shell` - Open MongoDB shell

## 🚀 Getting Started

### 1. Start MongoDB

```bash
# Start all services
make start

# Or start MongoDB only
docker-compose up -d mongodb
```

### 2. Initialize Replica Set

**Option A: Automatic (Recommended)**
```bash
# Wait for MongoDB to be healthy (30-60 seconds)
docker-compose ps mongodb

# Initialize replica set
make mongodb-init-replica
```

**Option B: Manual**
```bash
# Execute init script manually
docker exec mongodb bash /docker-entrypoint-initdb.d/init-replica.sh
```

### 3. Verify Setup

```bash
# Check status
make mongodb-status

# Should show:
# - stateStr: "PRIMARY"
# - health: 1
# - members: 1
```

## 🔌 Connection Strings

### Development (Local)

```bash
mongodb://binarydev:B1n4ryd3vc01d@localhost:27017/binarydb?replicaSet=rs0&authSource=admin
```

### Production (Remote)

```bash
mongodb://binarydev:YOUR_PASSWORD@43.163.118.150:27017/binarydb?replicaSet=rs0&authSource=admin
```

### Environment Variable

```bash
# Add to .env
MONGODB_URI=mongodb://binarydev:B1n4ryd3vc01d@localhost:27017/binarydb?replicaSet=rs0&authSource=admin
```

## 💻 Code Examples

### Next.js / Node.js

**1. Basic Connection (Mongoose)**

```typescript
// lib/mongodb.ts
import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI!;

if (!MONGODB_URI) {
  throw new Error('Please define MONGODB_URI in .env');
}

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function dbConnect() {
  if (cached.conn) {
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false,
      // Replica set specific options
      replicaSet: 'rs0',
      authSource: 'admin',
      retryWrites: true,
      w: 'majority',
    };

    cached.promise = mongoose.connect(MONGODB_URI, opts).then((mongoose) => {
      return mongoose;
    });
  }

  try {
    cached.conn = await cached.promise;
  } catch (e) {
    cached.promise = null;
    throw e;
  }

  return cached.conn;
}

export default dbConnect;
```

**2. Using Transactions**

```typescript
// lib/transfer-money.ts
import mongoose from 'mongoose';
import dbConnect from './mongodb';
import { Account } from '@/models/Account';

export async function transferMoney(
  fromAccountId: string,
  toAccountId: string,
  amount: number
) {
  await dbConnect();

  // Start a session
  const session = await mongoose.startSession();

  try {
    // Start transaction
    session.startTransaction();

    // Deduct from sender
    const fromAccount = await Account.findByIdAndUpdate(
      fromAccountId,
      { $inc: { balance: -amount } },
      { session, new: true }
    );

    if (!fromAccount || fromAccount.balance < 0) {
      throw new Error('Insufficient funds');
    }

    // Add to receiver
    await Account.findByIdAndUpdate(
      toAccountId,
      { $inc: { balance: amount } },
      { session, new: true }
    );

    // Commit transaction
    await session.commitTransaction();
    console.log('✅ Transfer successful');
    
    return { success: true };
  } catch (error) {
    // Rollback on error
    await session.abortTransaction();
    console.error('❌ Transfer failed:', error);
    throw error;
  } finally {
    session.endSession();
  }
}
```

**3. Using Change Streams**

```typescript
// lib/user-change-stream.ts
import mongoose from 'mongoose';
import dbConnect from './mongodb';
import { User } from '@/models/User';

export async function watchUserChanges() {
  await dbConnect();

  const changeStream = User.watch();

  changeStream.on('change', (change) => {
    console.log('📊 Change detected:', change.operationType);

    switch (change.operationType) {
      case 'insert':
        console.log('👤 New user:', change.fullDocument);
        // Send welcome email, create notifications, etc.
        break;

      case 'update':
        console.log('✏️ User updated:', change.documentKey._id);
        // Invalidate cache, sync to other services, etc.
        break;

      case 'delete':
        console.log('🗑️ User deleted:', change.documentKey._id);
        // Cleanup related data, send notifications, etc.
        break;

      case 'replace':
        console.log('🔄 User replaced:', change.documentKey._id);
        break;
    }
  });

  changeStream.on('error', (error) => {
    console.error('❌ Change stream error:', error);
  });

  return changeStream;
}

// Usage in your app
watchUserChanges().catch(console.error);
```

**4. API Route with Transaction**

```typescript
// app/api/orders/route.ts
import { NextRequest, NextResponse } from 'next/server';
import mongoose from 'mongoose';
import dbConnect from '@/lib/mongodb';
import { Order } from '@/models/Order';
import { Inventory } from '@/models/Inventory';

export async function POST(request: NextRequest) {
  await dbConnect();

  const session = await mongoose.startSession();

  try {
    session.startTransaction();

    const { items, userId, totalAmount } = await request.json();

    // Create order
    const order = await Order.create([{
      userId,
      items,
      totalAmount,
      status: 'pending'
    }], { session });

    // Update inventory for each item
    for (const item of items) {
      const result = await Inventory.findByIdAndUpdate(
        item.productId,
        { $inc: { stock: -item.quantity } },
        { session, new: true }
      );

      if (!result || result.stock < 0) {
        throw new Error(`Insufficient stock for product ${item.productId}`);
      }
    }

    await session.commitTransaction();

    return NextResponse.json({
      success: true,
      orderId: order[0]._id,
      message: 'Order created successfully'
    });

  } catch (error) {
    await session.abortTransaction();
    
    return NextResponse.json({
      success: false,
      error: error.message
    }, { status: 400 });

  } finally {
    session.endSession();
  }
}
```

## 🛠️ Management Commands

```bash
# Initialize replica set
make mongodb-init-replica

# Check replica set status
make mongodb-status

# View replica set configuration
make mongodb-config

# Open MongoDB shell
make mongodb-shell

# View MongoDB logs
make logs-mongodb

# Restart MongoDB
docker-compose restart mongodb
```

## 🔍 Verification

### Check Replica Set Status

```bash
make mongodb-status
```

Expected output:
```javascript
{
  "set": "rs0",
  "members": [
    {
      "_id": 0,
      "name": "mongodb:27017",
      "stateStr": "PRIMARY",  // ✅ Should be PRIMARY
      "health": 1,            // ✅ Should be 1
      "uptime": 123,
      // ... more info
    }
  ],
  "ok": 1
}
```

### Test Connection

```bash
# From container
docker exec mongodb mongosh \
  -u binarydev \
  -p B1n4ryd3vc01d \
  --authenticationDatabase admin \
  --eval "db.runCommand({ ping: 1 })"

# Should return: { ok: 1 }
```

### Test Transaction Support

```bash
docker exec mongodb mongosh \
  -u binarydev \
  -p B1n4ryd3vc01d \
  --authenticationDatabase admin \
  --eval "
    const session = db.getMongo().startSession();
    session.startTransaction();
    db.test.insertOne({ name: 'test' }, { session });
    session.commitTransaction();
    print('✅ Transactions working!');
  "
```

## 🐛 Troubleshooting

### Issue 1: Replica Set Not Initialized

**Error**: `MongoServerError: not master and slaveOk=false`

**Solution**:
```bash
# Initialize replica set
make mongodb-init-replica

# Check status
make mongodb-status
```

### Issue 2: Cannot Connect with replicaSet Parameter

**Error**: `MongoServerSelectionError: connect ECONNREFUSED`

**Solution**:
```bash
# Check if MongoDB is running
docker-compose ps mongodb

# Check if replica set is initialized
docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d \
  --authenticationDatabase admin --eval "rs.status()"

# If not initialized
make mongodb-init-replica
```

### Issue 3: Transactions Failing

**Error**: `MongoError: Transaction numbers are only allowed on a replica set member or mongos`

**Solution**:
```bash
# Verify replica set is PRIMARY
make mongodb-status
# Look for "stateStr": "PRIMARY"

# If not PRIMARY, reinitialize
docker-compose restart mongodb
sleep 30
make mongodb-init-replica
```

### Issue 4: KeyFile Permission Error

**Error**: `permissions on /data/keyfile/mongodb-keyfile are too open`

**Solution**:
```bash
# Fix keyfile permissions
chmod 400 config/mongodb/mongodb-keyfile

# Restart MongoDB
docker-compose restart mongodb
```

### Issue 5: Connection Timeout

**Solution**:
```bash
# Check logs
make logs-mongodb

# Restart and wait
docker-compose restart mongodb
sleep 30

# Initialize
make mongodb-init-replica
```

## 📊 Monitoring

### Check Replica Set Health

```bash
# Quick status
make mongodb-status | grep -E "stateStr|health"

# Detailed member info
docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d \
  --authenticationDatabase admin \
  --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr))"
```

### Check if Transactions are Enabled

```bash
docker exec mongodb mongosh -u binarydev -p B1n4ryd3vc01d \
  --authenticationDatabase admin \
  --eval "db.adminCommand({ getParameter: 1, transactionLifetimeLimitSeconds: 1 })"
```

### View Replica Set Configuration

```bash
make mongodb-config
```

## 🚀 Production Deployment

### Multi-Node Replica Set (3 Nodes)

For production with high availability, deploy 3-node replica set:

```yaml
# docker-compose.prod.yml
mongodb-primary:
  image: mongo:7
  hostname: mongodb-primary
  command: ["--replSet", "rs0", "--bind_ip_all", "--keyFile", "/data/keyfile/mongodb-keyfile"]
  environment:
    - MONGO_INITDB_ROOT_USERNAME=binarydev
    - MONGO_INITDB_ROOT_PASSWORD=secure_password
  ports:
    - "27017:27017"

mongodb-secondary-1:
  image: mongo:7
  hostname: mongodb-secondary-1
  command: ["--replSet", "rs0", "--bind_ip_all", "--keyFile", "/data/keyfile/mongodb-keyfile"]
  ports:
    - "27018:27017"

mongodb-secondary-2:
  image: mongo:7
  hostname: mongodb-secondary-2
  command: ["--replSet", "rs0", "--bind_ip_all", "--keyFile", "/data/keyfile/mongodb-keyfile"]
  ports:
    - "27019:27017"
```

Initialize with 3 members:
```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-primary:27017", priority: 2 },
    { _id: 1, host: "mongodb-secondary-1:27017", priority: 1 },
    { _id: 2, host: "mongodb-secondary-2:27017", priority: 1 }
  ]
});
```

Connection string:
```
mongodb://binarydev:password@mongodb-primary:27017,mongodb-secondary-1:27017,mongodb-secondary-2:27017/binarydb?replicaSet=rs0&authSource=admin
```

## 📚 Additional Resources

- [MongoDB Replica Set Documentation](https://www.mongodb.com/docs/manual/replication/)
- [Transactions in MongoDB](https://www.mongodb.com/docs/manual/core/transactions/)
- [Change Streams](https://www.mongodb.com/docs/manual/changeStreams/)
- [Mongoose Transactions](https://mongoosejs.com/docs/transactions.html)

## ✅ Summary

✅ MongoDB configured as Replica Set (`rs0`)
✅ KeyFile authentication enabled for security
✅ Auto-initialization script included
✅ Transaction support enabled
✅ Change Streams support enabled
✅ Production-ready configuration
✅ Management commands via Makefile
✅ Complete documentation provided

**Next Steps**:
1. Start MongoDB: `make start`
2. Initialize: `make mongodb-init-replica`
3. Verify: `make mongodb-status`
4. Connect: Use connection string in your app
5. Test: Try transactions and change streams!

---

**Need Help?** Check the troubleshooting section or run `make mongodb-status` to diagnose issues.
