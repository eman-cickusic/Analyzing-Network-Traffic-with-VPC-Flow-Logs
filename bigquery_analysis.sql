# SQL queries for analyzing VPC Flow Logs in BigQuery

# Query 1: Basic analysis of network traffic
# This query shows overall traffic patterns including source/destination IPs and ports
# Replace YOUR_TABLE_ID with your actual table ID
#standardSQL
SELECT
  jsonPayload.src_vpc.vpc_name,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes,
  jsonPayload.src_vpc.subnetwork_name,
  jsonPayload.connection.src_ip,
  jsonPayload.connection.src_port,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
FROM
  `YOUR_TABLE_ID`
GROUP BY
  jsonPayload.src_vpc.vpc_name,
  jsonPayload.src_vpc.subnetwork_name,
  jsonPayload.connection.src_ip,
  jsonPayload.connection.src_port,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
ORDER BY
  bytes DESC
LIMIT
  15;

# Query 2: Top IP addresses communicating with web server
# This query identifies top sources sending traffic to our web server
# Replace YOUR_TABLE_ID with your actual table ID
#standardSQL
SELECT
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
FROM
  `YOUR_TABLE_ID`
WHERE jsonPayload.reporter = 'DEST'
GROUP BY
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
ORDER BY
  bytes DESC
LIMIT
  15;

# Query 3: Traffic by protocol
# This query groups traffic by protocol to see distribution
# Replace YOUR_TABLE_ID with your actual table ID
#standardSQL
SELECT
  jsonPayload.connection.protocol,
  COUNT(*) AS connection_count,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM
  `YOUR_TABLE_ID`
GROUP BY
  jsonPayload.connection.protocol
ORDER BY
  total_bytes DESC;

# Query 4: Traffic over time
# This shows traffic patterns over time using the timestamp
# Replace YOUR_TABLE_ID with your actual table ID
#standardSQL
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS hour,
  COUNT(*) AS log_count,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM
  `YOUR_TABLE_ID`
GROUP BY
  hour
ORDER BY
  hour;

# Query 5: Potential port scan detection
# This query helps identify potential port scanning activity
# Replace YOUR_TABLE_ID with your actual table ID
#standardSQL
SELECT
  jsonPayload.connection.src_ip,
  COUNT(DISTINCT jsonPayload.connection.dest_port) AS unique_ports,
  MIN(timestamp) AS first_seen,
  MAX(timestamp) AS last_seen
FROM
  `YOUR_TABLE_ID`
GROUP BY
  jsonPayload.connection.src_ip
HAVING
  unique_ports > 5
ORDER BY
  unique_ports DESC;
