-- Create indexes for oauth2_clients table
-- This script is idempotent and can be run multiple times safely

USE client_db;

-- Index for filtering active clients (improves WHERE is_active = true queries)
CREATE INDEX idx_active ON oauth2_clients (is_active);

-- Index for searching by client name (improves WHERE client_name LIKE queries)
CREATE INDEX idx_name ON oauth2_clients (client_name);
