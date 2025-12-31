# InfluxDB Stack

This stack deploys InfluxDB, an open-source time series database optimized for fast, high-availability storage and retrieval of time series data.

## Overview

InfluxDB is designed for recording metrics, events, and analytics. It's commonly used with Telegraf for metrics collection and Grafana for visualization (the TIG stack).

## Prerequisites

- Docker Swarm environment
- Git repository containing InfluxDB configuration
- SSH key for accessing the Git configuration repository

## Required Environment Variables

Configure these before deployment:

### InfluxDB Port
- `INFLUX_PORT`: Port to expose InfluxDB (default: `8086`)

### Database Configuration
- `DB`: Initial database name to create

### Admin User
- `ADMIN_USER`: Admin username
- `ADMIN_PASSWORD`: Admin password

### Regular User (Read/Write)
- `USER`: Username for regular user
- `USER_PASSWORD`: Password for regular user

### Read-Only User
- `READ_USER`: Username for read-only access
- `READ_USER_PASSWORD`: Password for read-only user

### Write-Only User
- `WRITE_USER`: Username for write-only access
- `WRITE_USER_PASSWORD`: Password for write-only user

### Git Configuration Repository
- `CONFIG_REPO`: **Required** - URL of the Git repository containing InfluxDB configuration
- `CONFIG_BRANCH`: Git branch to use (default: `master`)
- `GIT_USER`: Git username (default: `git`)

### Docker Secrets
- `GIT_KEY`: Name of the Docker secret containing SSH key for Git access (default: `git_reader_key`)

## Pre-Deployment Setup

### 1. Create Docker Secret for Git Access

```bash
# Create secret from SSH private key
docker secret create git_reader_key ~/.ssh/id_rsa

# Or use custom name and update GIT_KEY variable
docker secret create config_reader_key /path/to/ssh/key
```

### 2. Prepare Configuration Repository

Create a Git repository with InfluxDB configuration. Example structure:

```
influxdb-config/
└── influxdb.conf
```

### 3. Example InfluxDB Configuration

Create `influxdb.conf` in your Git repository:

```toml
[meta]
  dir = "/var/lib/influxdb/meta"

[data]
  dir = "/var/lib/influxdb/data"
  wal-dir = "/var/lib/influxdb/wal"

  # Controls the cache
  cache-max-memory-size = 1073741824  # 1GB
  cache-snapshot-memory-size = 26214400  # 25MB
  cache-snapshot-write-cold-duration = "10m"

  # Retention policy settings
  compact-full-write-cold-duration = "4h"
  max-series-per-database = 1000000
  max-values-per-tag = 100000

[coordinator]
  write-timeout = "10s"
  max-concurrent-queries = 0
  query-timeout = "0s"
  log-queries-after = "0s"
  max-select-point = 0
  max-select-series = 0
  max-select-buckets = 0

[retention]
  enabled = true
  check-interval = "30m"

[http]
  enabled = true
  bind-address = ":8086"
  auth-enabled = true
  log-enabled = true
  write-tracing = false
  pprof-enabled = true
  https-enabled = false
  max-row-limit = 0
  max-connection-limit = 0
  shared-secret = ""
  realm = "InfluxDB"
```

### 4. Set Environment Variables

```bash
export INFLUX_PORT=8086
export DB=telegraf
export ADMIN_USER=admin
export ADMIN_PASSWORD="your_secure_admin_password"
export USER=telegraf
export USER_PASSWORD="telegraf_user_password"
export READ_USER=grafana
export READ_USER_PASSWORD="grafana_read_password"
export WRITE_USER=writer
export WRITE_USER_PASSWORD="writer_password"
export CONFIG_REPO="git@github.com:youruser/influxdb-config.git"
export GIT_KEY=git_reader_key
```

## Services Included

### server
- InfluxDB time series database
- Exposes port 8086 for HTTP API
- Uses configuration from Git repository
- Persistent storage for data

### config
- Pulls InfluxDB configuration from Git repository
- Runs once at startup
- Mounts configuration read-only to server

## Post-Deployment Configuration

### 1. Verify InfluxDB is Running

```bash
docker service ps <stack>_server
```

### 2. Access InfluxDB CLI

```bash
# Find container
docker ps | grep influxdb

# Access InfluxDB shell
docker exec -it <container_id> influx

# Login
> auth
username: admin
password: your_admin_password

# Show databases
> SHOW DATABASES

# Use your database
> USE telegraf

# Show measurements
> SHOW MEASUREMENTS
```

### 3. Test HTTP API

```bash
# Check status
curl -sl -I http://<server-ip>:8086/ping

# Query databases (with authentication)
curl -G 'http://<server-ip>:8086/query' \
  --data-urlencode "q=SHOW DATABASES" \
  -u admin:your_admin_password

# Write data
curl -X POST 'http://<server-ip>:8086/write?db=telegraf' \
  --data-binary 'cpu,host=server01,region=us-west value=0.64' \
  -u telegraf:telegraf_user_password
```

## Architecture

```
┌──────────────┐
│   config     │ ──> Pulls from Git (once)
└──────────────┘
       │
       ▼
┌──────────────┐
│ InfluxDB     │ ──> Persistent Storage
│  Server      │     (server-data volume)
└──────────────┘
       ▲
       │
  Port 8086 (HTTP API)
```

## Volumes

- `server-config`: InfluxDB configuration from Git (read-only)
- `server-data`: InfluxDB data files (persistent)

## User Permissions

This stack creates four types of users:

1. **Admin User**: Full administrative access
   - Can create/drop databases
   - Manage users and permissions
   - Execute all queries

2. **Regular User**: Read and write access to database
   - Can write and query data
   - Cannot manage database or users

3. **Read-Only User**: Read access only
   - Can query data
   - Cannot write or modify data
   - Ideal for Grafana

4. **Write-Only User**: Write access only
   - Can write data
   - Cannot query data
   - Ideal for data ingestion services

## Database Operations

### Create a Database

```sql
CREATE DATABASE mydb
```

### Create Retention Policy

```sql
-- Keep data for 30 days
CREATE RETENTION POLICY "30_days" ON "telegraf" DURATION 30d REPLICATION 1 DEFAULT

-- Keep data for 1 year with 1h aggregation
CREATE RETENTION POLICY "1_year" ON "telegraf" DURATION 52w REPLICATION 1
```

### Show Retention Policies

```sql
SHOW RETENTION POLICIES ON telegraf
```

### Write Data

```sql
INSERT cpu,host=server01,region=us-west value=0.64
```

### Query Data

```sql
-- Select recent data
SELECT * FROM cpu WHERE time > now() - 1h

-- Aggregate data
SELECT mean(value) FROM cpu WHERE time > now() - 24h GROUP BY time(1h), host
```

### Delete Data

```sql
DROP MEASUREMENT cpu
DROP DATABASE mydb
```

## Integration with Telegraf

### Telegraf Output Configuration

```toml
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "telegraf"
  username = "telegraf"
  password = "telegraf_user_password"
  retention_policy = ""
  write_consistency = "any"
  timeout = "5s"
```

## Integration with Grafana

### Add InfluxDB Data Source

1. Open Grafana
2. Go to Configuration > Data Sources
3. Add InfluxDB:
   - URL: `http://influxdb:8086`
   - Database: `telegraf`
   - User: `grafana` (read-only user)
   - Password: `grafana_read_password`
   - HTTP Method: GET

## Security Considerations

1. **Change Default Passwords**: Use strong, unique passwords for all users
2. **Enable Authentication**: The configuration enables auth by default
3. **Use HTTPS**: For production, enable HTTPS in configuration
4. **Network Isolation**: Run on a private network when possible
5. **Backup Regularly**: Backup the `server-data` volume
6. **Least Privilege**: Use read-only user for visualization tools
7. **Git Access**: Ensure SSH key has read-only access to config repository

## Performance Tuning

### Memory Management

```toml
[data]
  # Increase cache for better write performance
  cache-max-memory-size = 2147483648  # 2GB

  # Adjust snapshot size
  cache-snapshot-memory-size = 52428800  # 50MB
```

### Query Optimization

```toml
[coordinator]
  # Limit concurrent queries
  max-concurrent-queries = 10

  # Set query timeout
  query-timeout = "30s"

  # Limit points per query
  max-select-point = 10000000
```

### Retention Policies

Use retention policies to automatically delete old data:

```sql
-- Data older than 7 days is automatically deleted
CREATE RETENTION POLICY "7_days" ON "telegraf" DURATION 7d REPLICATION 1 DEFAULT
```

### Continuous Queries

Automatically downsample data:

```sql
-- Create aggregated data every hour
CREATE CONTINUOUS QUERY "cq_30m" ON "telegraf"
BEGIN
  SELECT mean("value") INTO "telegraf"."1_year".:MEASUREMENT
  FROM "telegraf"."30_days"./.*/
  GROUP BY time(30m), *
END
```

## Backup and Restore

### Backup Database

```bash
# Backup to file
docker exec <container> influxd backup -portable /tmp/backup
docker cp <container>:/tmp/backup ./influxdb_backup

# Backup specific database
docker exec <container> influxd backup -portable -database telegraf /tmp/backup
```

### Restore Database

```bash
# Copy backup to container
docker cp ./influxdb_backup <container>:/tmp/backup

# Restore
docker exec <container> influxd restore -portable /tmp/backup
```

### Automated Backups

Create a backup script:

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER=$(docker ps | grep influxdb | awk '{print $1}')
docker exec $CONTAINER influxd backup -portable /tmp/backup_$DATE
docker cp $CONTAINER:/tmp/backup_$DATE ./backups/
```

## Monitoring

### Check Database Size

```sql
SHOW STATS
```

### Monitor Write Performance

```sql
SELECT * FROM "_internal"."monitor"."write" WHERE time > now() - 1h
```

### Check Query Performance

```sql
SELECT * FROM "_internal"."monitor"."queryExecutor" WHERE time > now() - 1h
```

## Troubleshooting

### Cannot Connect to InfluxDB

1. Check service is running: `docker service ps <stack>_server`
2. Verify port is exposed: `docker service inspect <stack>_server`
3. Test connectivity: `curl http://<server-ip>:8086/ping`
4. Check logs: `docker service logs <stack>_server`

### Authentication Errors

1. Verify credentials are correct
2. Check auth is enabled in configuration
3. Test with CLI: `influx -username admin -password your_password`

### Slow Queries

1. Check query complexity
2. Add indexes with WHERE clauses
3. Use time ranges in queries
4. Consider downsampling with continuous queries
5. Check `max-select-point` limit

### High Memory Usage

1. Reduce `cache-max-memory-size`
2. Implement retention policies
3. Use continuous queries to downsample
4. Delete unused measurements

### Configuration Not Updating

1. Verify Git repository is accessible
2. Check config service logs: `docker service logs <stack>_config`
3. Verify SSH key secret is correct
4. Force update: `docker service update --force <stack>_config`

## Maintenance

### Regular Tasks

- Weekly: Check database size and growth
- Weekly: Review slow queries
- Monthly: Test backup and restore
- Monthly: Review and optimize retention policies
- Quarterly: Update InfluxDB version

### Upgrade InfluxDB

```bash
# Backup first!
docker exec <container> influxd backup -portable /tmp/backup

# Update image
docker service update --image influxdb:alpine <stack>_server
```

## Documentation

- [InfluxDB Documentation](https://docs.influxdata.com/influxdb/)
- [InfluxQL Reference](https://docs.influxdata.com/influxdb/latest/query_language/)
- [Schema Design](https://docs.influxdata.com/influxdb/latest/concepts/schema_and_data_layout/)
- [Hardware Sizing](https://docs.influxdata.com/influxdb/latest/guides/hardware_sizing/)

## Quick Reference

```bash
# Access CLI
docker exec -it <container> influx -username admin -password <password>

# Show databases
SHOW DATABASES

# Use database
USE telegraf

# Show measurements
SHOW MEASUREMENTS

# Query recent data
SELECT * FROM cpu WHERE time > now() - 1h

# Create retention policy
CREATE RETENTION POLICY "30_days" ON "telegraf" DURATION 30d REPLICATION 1

# Backup
docker exec <container> influxd backup -portable /tmp/backup

# View logs
docker service logs <stack>_server
```
