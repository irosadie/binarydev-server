-- PostgreSQL initialization script
-- This script creates the main database and sets up basic configurations

-- Create the main database if it doesn't exist
SELECT 'CREATE DATABASE binarydb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'binarydb')\gexec

-- Create the test database if it doesn't exist
SELECT 'CREATE DATABASE binarydb_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'binarydb_test')\gexec

-- Connect to the main database
\c binarydb;

-- Create extensions that might be needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create a basic table for health checks
CREATE TABLE IF NOT EXISTS health_check (
    id SERIAL PRIMARY KEY,
    status VARCHAR(50) DEFAULT 'healthy',
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial health check record
INSERT INTO health_check (status) VALUES ('healthy') ON CONFLICT DO NOTHING;

-- Grant necessary permissions to the user
GRANT ALL PRIVILEGES ON DATABASE binarydb TO binarydev;
GRANT ALL PRIVILEGES ON DATABASE binarydb_test TO binarydev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO binarydev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO binarydev;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO binarydev;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO binarydev;
