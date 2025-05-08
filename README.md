# Analyzing Network Traffic with VPC Flow Logs

## Overview
This project demonstrates how to configure a network to record traffic to and from an Apache web server using VPC Flow Logs, and then export those logs to BigQuery for analysis.

## Objectives
- Configure a custom network with VPC flow logs
- Create an Apache web server
- Verify that network traffic is logged
- Export the network traffic to BigQuery to analyze the logs
- Set up VPC flow log aggregation to optimize logging costs

## Architecture Diagram
```
┌──────────────────┐     ┌───────────────┐     ┌───────────────┐
│                  │     │               │     │               │
│  External Users  │◄───►│ Apache Server │◄───►│  VPC Flow Logs│
│                  │     │               │     │               │
└──────────────────┘     └───────┬───────┘     └───────┬───────┘
                                 │                     │
                                 │                     ▼
                                 │             ┌───────────────┐
                                 │             │               │
                                 └────────────►│   BigQuery    │
                                               │               │
                                               └───────────────┘
```

## Prerequisites
- A Google Cloud Platform account
- Basic understanding of networking concepts
- Familiarity with Google Cloud Console

## Video

https://youtu.be/6z8rGhGyjjA


## Step-by-Step Implementation

### Task 1: Configure a custom network with VPC flow logs

#### Create the custom network
1. In the Google Cloud console, navigate to **VPC network > VPC networks**
2. Click **Create VPC Network**
3. Configure the network with these settings:
   - Name: `vpc-net`
   - Subnet creation mode: `Custom`
   - Subnet configuration:
     - Name: `vpc-subnet`
     - Region: Select your preferred region
     - IP address range: `10.1.3.0/24`
     - Flow Logs: `On`
4. Click **Create**

#### Create the firewall rule
1. Navigate to **VPC network > Firewall**
2. Click **CREATE FIREWALL RULE**
3. Configure with these settings:
   - Name: `allow-http-ssh`
   - Network: `vpc-net`
   - Targets: `Specified target tags`
   - Target tags: `http-server`
   - Source filter: `IPv4 Ranges`
   - Source IPv4 ranges: `0.0.0.0/0`
   - Protocols and ports: Select `tcp`, specify ports `80, 22`
4. Click **Create**

### Task 2: Create an Apache web server

#### Create the VM instance
1. Navigate to **Compute Engine > VM instances**
2. Click **Create instance**
3. Configure the instance:
   - Name: `web-server`
   - Machine type: `e2-micro`
   - Network tags: `http-server`
   - Network interface:
     - Network: `vpc-net`
     - Subnetwork: `vpc-subnet`
4. Click **Create**

#### Install Apache
1. SSH into the `web-server` VM
2. Update package index:
   ```bash
   sudo apt-get update
   ```
3. Install Apache:
   ```bash
   sudo apt-get install apache2 -y
   ```
4. Create a custom homepage:
   ```bash
   echo '<!doctype html><html><body><h1>Hello World!</h1></body></html>' | sudo tee /var/www/html/index.html
   ```
5. Exit the SSH session

### Task 3: Verify that network traffic is logged

#### Generate network traffic
1. Access the web server by clicking the external IP in the VM details
2. Find your own IP address by searching "what's my IP" on Google

#### Access the VPC flow logs
1. Navigate to **Logging**
2. In the Log fields panel:
   - Select **RESOURCE TYPE** > **Subnetwork**
   - Select **LOG NAME** > **compute.googleapis.com/vpc_flows**
3. Add your IP address to the query and run it
4. Examine the log entries, focusing on connection fields:
   - Source IP address
   - Source port
   - Destination IP address
   - Destination port
   - IANA protocol number

### Task 4: Export the network traffic to BigQuery

#### Create an export sink
1. In Logs explorer, select **RESOURCE TYPE** > **Subnetwork**
2. Select **LOG NAME** > **compute.googleapis.com/vpc_flows**
3. Select **Actions > Create Sink**
4. Configure the sink:
   - Name: `bq_vpcflows`
   - Sink service: **BigQuery dataset**
   - Create new dataset: `bq_vpcflows`
5. Click **CREATE SINK**

#### Generate log traffic for BigQuery
1. Note the external IP of the web server
2. Use Cloud Shell to access the server multiple times:
   ```bash
   export MY_SERVER=<External_IP>
   for ((i=1;i<=50;i++)); do curl $MY_SERVER; done
   ```

#### Analyze in BigQuery
1. Navigate to **BigQuery**
2. Expand your dataset and locate the table
3. Run the following query to analyze traffic patterns (replace `your_table_id`):

```sql
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
  `your_table_id`
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
  15
```

4. Run a more focused query to identify top traffic sources:

```sql
#standardSQL
SELECT
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
FROM
  `your_table_id`
WHERE jsonPayload.reporter = 'DEST'
GROUP BY
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
ORDER BY
  bytes DESC
LIMIT
  15
```

### Task 5: Optimize with VPC flow log aggregation

1. Navigate to **VPC network > VPC networks**
2. Click on `vpc-net`
3. Select the `vpc-subnet` subnet and click **Edit**
4. Navigate to **Advanced Settings** and configure:
   - Aggregation Interval: `30 seconds` (reduces log size by up to 83%)
   - Secondary sampling rate: `25%`
5. Click **Save**

## Cost Optimization
VPC Flow Logs can generate significant amounts of data. Here are ways to optimize costs:

- **Adjust aggregation interval**: Increase from default 5 seconds to 30 seconds or higher
- **Reduce sampling rate**: Use sampling to capture only a percentage of traffic
- **Disable metadata annotations**: Turn off when detailed metadata isn't needed
- **Use BigQuery partitioning**: When exporting to BigQuery, use partitioned tables

## Troubleshooting

### Common Issues

1. **Missing VPC flow logs**:
   - Ensure Flow Logs are enabled for the subnet
   - Wait a few minutes for logs to appear
   - Generate more traffic to the server

2. **BigQuery sink not working**:
   - Verify sink configuration and permissions
   - Check if the dataset exists

3. **High logging costs**:
   - Review and adjust aggregation settings
   - Consider reducing sampling rate

## Additional Resources

- [VPC Flow Logs Documentation](https://cloud.google.com/vpc/docs/flow-logs)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
