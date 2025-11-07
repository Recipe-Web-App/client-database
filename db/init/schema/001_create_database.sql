-- Create client_db database
-- This script is idempotent and can be run multiple times safely

CREATE DATABASE IF NOT EXISTS client_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE client_db;
