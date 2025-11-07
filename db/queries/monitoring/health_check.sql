-- Health check query for monitoring oauth2_clients table
-- Returns client counts and current status

USE client_db;

SELECT
  'healthy' AS status,
  COUNT(*) AS total_clients,
  SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_clients,
  SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) AS inactive_clients,
  NOW() AS checked_at
FROM oauth2_clients;
