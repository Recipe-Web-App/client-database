-- Create oauth2_clients table for storing OAuth2 client credentials
-- This script is idempotent and can be run multiple times safely

USE client_db;

CREATE TABLE IF NOT EXISTS oauth2_clients (
  -- Primary Key
  client_id VARCHAR(255) PRIMARY KEY COMMENT 'Unique OAuth2 client identifier',

  -- Credentials
  client_secret_hash VARCHAR(255) NOT NULL COMMENT 'bcrypt hash of the client secret',

  -- Client Metadata
  client_name VARCHAR(255) NOT NULL COMMENT 'Human-readable client name',
  grant_types JSON NOT NULL COMMENT 'Array of OAuth2 grant types (e.g., ["client_credentials"])',
  scopes JSON NOT NULL COMMENT 'Array of allowed scopes (e.g., ["read", "write"])',
  redirect_uris JSON NULL COMMENT 'Array of allowed redirect URIs for authorization code flow',

  -- Status
  is_active BOOLEAN DEFAULT TRUE COMMENT 'Whether the client is currently active',

  -- Audit Fields
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When the client was created',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When the client was last updated',
  created_by VARCHAR(255) NULL COMMENT 'User or system that created this client',

  -- Extensibility
  metadata JSON NULL COMMENT 'Additional extensible metadata for future use'
) ENGINE = InnoDB
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci
COMMENT = 'OAuth2 client credentials storage';
