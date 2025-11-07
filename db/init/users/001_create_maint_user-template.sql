-- Create maintenance user for database operations
-- This template uses envsubst for environment variable substitution
-- Run with: envsubst < 001_create_maint_user-template.sql | mysql -u root -p

-- Create db-maint-user with full privileges except DROP DATABASE
CREATE USER IF NOT EXISTS 'db-maint-user'@'%' IDENTIFIED BY '${MYSQL_MAINT_PASSWORD}';

-- Grant all privileges on client_db database (but not global DROP DATABASE)
GRANT ALL PRIVILEGES ON client_db.* TO 'db-maint-user'@'%';

-- Apply changes
FLUSH PRIVILEGES;
