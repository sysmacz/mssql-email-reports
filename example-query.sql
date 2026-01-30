-- example-query.sql
-- Sample query for SQL-Reports. Replace with your real report query.
-- This template shows a typical "per-user per-day" aggregation for yesterday.

DECLARE @from datetime2(0) = DATEADD(day, DATEDIFF(day, 0, GETDATE()) - 1, 0);
DECLARE @to   datetime2(0) = DATEADD(day, DATEDIFF(day, 0, GETDATE()),     0);

SELECT
    CAST(ReportedTime AS date) AS ReportDate,
    ISNULL(UserLogin, 'UNKNOWN') AS UserLogin,
    COUNT(DISTINCT AlertID) AS AlertCount
FROM YourSchema.YourAlertsTable -- <- REPLACE with your schema.table
WHERE ReportedTime >= @from
  AND ReportedTime <  @to
GROUP BY CAST(ReportedTime AS date), ISNULL(UserLogin, 'UNKNOWN')
ORDER BY ReportDate, AlertCount DESC;
