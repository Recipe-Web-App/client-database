-- Create auth-service application user
-- This template uses envsubst for environment variable substitution
-- Run with: envsubst < 002_create_auth_service_user-template.sql | mysql -u root -p

-- Create auth-service-user with CRUD permissions
CREATE USER IF NOT EXISTS 'auth-service-user'@'%' IDENTIFIED BY '${MYSQL_AUTH_PASSWORD}';

-- Grant SELECT, INSERT, UPDATE, DELETE on client_db database
GRANT SELECT, INSERT, UPDATE, DELETE ON client_db.* TO 'auth-service-user'@'%';

-- Apply changes
FLUSH PRIVILEGES;
