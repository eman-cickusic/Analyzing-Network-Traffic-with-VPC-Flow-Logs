# Cost Optimization Guide for VPC Flow Logs

VPC Flow Logs can generate significant volumes of data, which may lead to increased costs in Cloud Logging and BigQuery storage. This guide provides strategies to optimize costs while maintaining the necessary visibility into your network traffic.

## Understanding VPC Flow Logs Cost Factors

Several factors affect the cost of VPC Flow Logs:

1. **Volume of network traffic** - More traffic generates more logs
2. **Number of VM instances** - Each instance with network traffic generates logs
3. **Log retention period** - Longer retention increases storage costs
4. **Export destinations** - Different destinations have different cost structures
5. **Log configuration** - Sampling rate and aggregation interval affect volume

## Cost Optimization Strategies

### 1. Optimize VPC Flow Logs Configuration

#### Aggregation Interval

Increasing the aggregation interval reduces the number of log entries:

| Aggregation Interval | Reduction in Log Size |
|--------------------|----------------------|
| 5 seconds (default) | 0% (baseline) |
| 30 seconds | Up to 83% |
| 1 minute | Up to 91% |
| 5 minutes | Up to 98% |
| 10 minutes | Up to 99% |
| 15 minutes | Up to 99.4% |

**Recommendation:** Use 30-second to 5-minute intervals for most scenarios. Only use 5-second intervals for critical systems where immediate detection is essential.

#### Sampling Rate

Adjust the sampling rate to capture only a percentage of logs:

| Sampling Rate | Data Volume |
|--------------|------------|
| 1.0 (100%) | All logs captured |
| 0.5 (50%) | Half of logs captured |
| 0.25 (25%) | Quarter of logs captured |
| 0.1 (10%) | One-tenth of logs captured |

**Recommendation:** Start with 50% sampling for general monitoring. Use higher rates only when detailed analysis is needed.

#### Metadata Annotations

Disabling metadata annotations can reduce log size:

```
gcloud compute networks subnets update vpc-subnet \
    --region=REGION \
    --no-enable-flow-logs-metadata
```

### 2. Optimize BigQuery Storage

When exporting VPC Flow Logs to BigQuery:

#### Use Table Partitioning

Partition BigQuery tables by date to improve query performance and reduce costs:

```sql
CREATE OR REPLACE TABLE `PROJECT_ID.DATASET.vpc_flow_logs_partitioned`
PARTITION BY DATE(timestamp) AS
SELECT * FROM `PROJECT_ID.DATASET.vpc_flow_logs`
```

#### Set Up Automatic Table Expiration

Configure table partitions to expire after a certain period:

```sql
CREATE OR REPLACE TABLE `PROJECT_ID.DATASET.vpc_flow_logs_partitioned`
PARTITION BY DATE(timestamp)
OPTIONS(
  partition_expiration_days=30
) AS
SELECT * FROM `PROJECT_ID.DATASET.vpc_flow_logs`
```

### 3. Filter Logs Before Export

Export only the logs you need by using appropriate filters in your sink:

```
gcloud logging sinks create filtered-vpc-flows \
    bigquery.googleapis.com/projects/PROJECT_ID/datasets/DATASET_ID \
    --log-filter="resource.type=subnetwork AND logName=projects/PROJECT_ID/logs/compute.googleapis.com%2Fvpc_flows AND jsonPayload.reporter=\"SRC\""
```

### 4. Set Up Budget Alerts

Create budget alerts in Google Cloud to monitor and get notifications about your logging costs:

1. Navigate to **Billing > Budgets & Alerts**
2. Create a budget specifically for logging services
3. Set alert thresholds (e.g., 50%, 75%, 90% of budget)

## Cost-Benefit Analysis

| Configuration | Cost Impact | Visibility Impact | Recommended For |
|--------------|------------|------------------|----------------|
| Default (5s, 100%) | Highest | Highest | Security-critical workloads |
| Moderate (30s, 50%) | Medium | Good | Production environments |
| Economy (5m, 25%) | Low | Basic | Development/test environments |
| Minimal (15m, 10%) | Lowest | Limited | Non-critical infrastructure |

## Monitoring Your Costs

Regularly review your costs using:

1. **Billing Reports** - Filter by service (Logging, BigQuery)
2. **Logs Dashboard** - Check log volume trends
3. **BigQuery Information Schema** - Query table metadata for storage usage

```sql
SELECT
  table_name,
  SUM(total_rows) as rows,
  SUM(size_bytes)/POWER(1024, 3) AS size_gb
FROM
  `PROJECT_ID.DATASET.__TABLES__`
GROUP BY table_name
ORDER BY size_gb DESC
```

By implementing these cost optimization strategies, you can maintain effective network monitoring with VPC Flow Logs while controlling your cloud spending.
