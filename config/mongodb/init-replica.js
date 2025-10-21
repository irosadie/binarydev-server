// Minimal init script to initiate single-node replica set if not yet initialized
// Reads env vars passed through docker env

(function () {
  try {
    const rsName = process.env.MONGO_REPLICA_SET_NAME || 'rs0';
    const host = process.env.MONGO_REPLICA_SET_HOST || 'mongodb:27017';

    // Use admin DB for running rs.initiate
    const admin = db.getSiblingDB('admin');

    // If already initiated, exit quietly
    try {
      const status = admin.runCommand({ replSetGetStatus: 1 });
      if (status && status.ok === 1) {
        print(`Replica set already initialized: ${status.set}`);
        return;
      }
    } catch (e) {
      // replSetGetStatus will fail if not initiated yet; proceed to initiate
    }

    const cfg = {
      _id: rsName,
      members: [
        { _id: 0, host },
      ],
    };

    const res = admin.runCommand({ replSetInitiate: cfg });
    printjson(res);
  } catch (err) {
    print(`Init replica error: ${err}`);
  }
})();
