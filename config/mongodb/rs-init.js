// Idempotent single-node replica set initialization
// Runs only on first container startup when /data/db is empty

try {
  const rsName = process.env.MONGO_REPLICA_SET_NAME || 'rs0';

  // If already initiated, this will throw or return a status
  const status = rs.status();
  if (status && status.ok === 1) {
    print(`Replica set already initialized: ${status.set}`);
  }
} catch (e) {
  // Not yet initiated; proceed with initialization
  const rsName = process.env.MONGO_REPLICA_SET_NAME || 'rs0';
  print(`Initializing replica set '${rsName}'...`);
  rs.initiate({
    _id: rsName,
    members: [{ _id: 0, host: 'localhost:27017' }],
  });

  // Wait until PRIMARY
  let attempts = 0;
  while (attempts < 60) { // up to ~60s
    try {
      const st = rs.status();
      const isPrimary = st.members && st.members.some(m => m.stateStr === 'PRIMARY');
      if (isPrimary) {
        print('Replica set PRIMARY ready.');
        break;
      }
    } catch (err) {}
    sleep(1000);
    attempts++;
  }

  // Create admin user if env provided
  const user = _getEnv('MONGO_INITDB_ROOT_USERNAME');
  const pass = _getEnv('MONGO_INITDB_ROOT_PASSWORD');
  if (user && pass) {
    print('Creating admin user...');
    db.getSiblingDB('admin').createUser({
      user: user,
      pwd: pass,
      roles: [
        { role: 'root', db: 'admin' },
      ],
    });
    print('Admin user created.');
  }
}

function _getEnv(key) {
  try {
    // mongosh exposes process.env; legacy mongo shell does not; guard just in case
    return (process && process.env && process.env[key]) || '';
  } catch (_) {
    return '';
  }
}
