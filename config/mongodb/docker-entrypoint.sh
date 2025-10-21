#!/bin/bash
set -e

# Copy keyFile to writable location and fix permissions (required by MongoDB)
if [ -f /data/keyfile ]; then
    cp /data/keyfile /tmp/mongodb-keyfile
    chmod 400 /tmp/mongodb-keyfile
    chown mongodb:mongodb /tmp/mongodb-keyfile
    export KEYFILE_PATH=/tmp/mongodb-keyfile
fi

# Run original MongoDB entrypoint with modified keyfile path
exec docker-entrypoint.sh "$@"
