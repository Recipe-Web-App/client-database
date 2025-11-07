-- Sample OAuth2 client credentials for testing and development
-- This script is idempotent and can be run multiple times safely

USE client_db;

-- Sample Client 1: Service-to-Service API Gateway
-- client_id: api-gateway-prod
-- client_secret: gateway_secret_key_123 (plaintext for reference only)
-- client_secret_hash: bcrypt hash with cost factor 10
INSERT INTO oauth2_clients (
  client_id,
  client_secret_hash,
  client_name,
  grant_types,
  scopes,
  redirect_uris,
  is_active,
  created_by,
  metadata
) VALUES (
  'api-gateway-prod',
  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
  'Production API Gateway',
  '["client_credentials"]',
  '["read", "write"]',
  NULL,
  TRUE,
  'platform-admin',
  '{"environment": "production", "region": "us-east-1", "service_type": "api-gateway"}'
) ON DUPLICATE KEY UPDATE
client_secret_hash = VALUES (client_secret_hash),
client_name = VALUES (client_name),
grant_types = VALUES (grant_types),
scopes = VALUES (scopes),
is_active = VALUES (is_active),
metadata = VALUES (metadata);

-- Sample Client 2: User-Facing Web Application
-- client_id: web-app-v1
-- client_secret: web_app_secret_xyz_789 (plaintext for reference only)
-- client_secret_hash: bcrypt hash with cost factor 10
INSERT INTO oauth2_clients (
  client_id,
  client_secret_hash,
  client_name,
  grant_types,
  scopes,
  redirect_uris,
  is_active,
  created_by,
  metadata
) VALUES (
  'web-app-v1',
  '$2a$10$VNRZhq6X7ZWLKHwqR5V7qOXKc3FZRQn1VRH3tXMPQ8ZE0FQN5QJXC',
  'Web Application v1',
  '["authorization_code", "refresh_token"]',
  '["profile", "email", "read"]',
  '["https://app.example.com/callback", "https://app.example.com/silent-refresh"]',
  TRUE,
  'web-team',
  '{"environment": "production", "version": "1.0.0", "framework": "react"}'
) ON DUPLICATE KEY UPDATE
client_secret_hash = VALUES (client_secret_hash),
client_name = VALUES (client_name),
grant_types = VALUES (grant_types),
scopes = VALUES (scopes),
redirect_uris = VALUES (redirect_uris),
is_active = VALUES (is_active),
metadata = VALUES (metadata);
