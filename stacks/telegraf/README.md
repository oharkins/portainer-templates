# Telegraf Stack

This stack deploys Telegraf, an open-source agent for collecting metrics and data written in Go.

## Overview

Telegraf is a plugin-driven server agent for collecting and sending metrics and events from databases, systems, and IoT sensors. This deployment runs Telegraf globally across all Docker Swarm nodes for comprehensive monitoring.

## Prerequisites

- Docker Swarm environment
- Git repository containing Telegraf configuration
- SSH key for accessing the Git configuration repository
- Target metrics destination (e.g., InfluxDB, Prometheus, etc.)

## Required Environment Variables

Configure these before deployment:

### Git Configuration Repository
- `CONFIG_REPO`: **Required** - URL of the Git repository containing Telegraf configuration files
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

Create a Git repository with Telegraf configuration. Example structure:

```
telegraf-config/
└── telegraf.conf
```

### 3. Example Telegraf Configuration

Create `telegraf.conf` in your Git repository:

```toml
# Global Agent Configuration
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

# Output Plugin - InfluxDB
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "telegraf"
  username = "telegraf"
  password = "your_password"
  retention_policy = ""
  write_consistency = "any"
  timeout = "5s"

# Input Plugins
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.swap]]

[[inputs.system]]

[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
  gather_services = false
  container_names = []
  source_tag = false
  container_name_include = []
  container_name_exclude = []
  timeout = "5s"
  perdevice = true
  total = false
  docker_label_include = []
  docker_label_exclude = []

[[inputs.net]]
  interfaces = ["eth*"]
```

## Services Included

### agent
- Telegraf monitoring agent
- Deployed globally (one instance per swarm node)
- Collects metrics from each node
- Has access to Docker socket for container metrics

### config
- Pulls Telegraf configuration from Git repository
- Runs once at startup
- Mounts configuration read-only to agents

## Post-Deployment Configuration

### 1. Verify Telegraf is Running

Check Telegraf agents on all nodes:

```bash
docker service ps <stack>_agent
```

### 2. View Telegraf Logs

```bash
docker service logs <stack>_agent
```

### 3. Verify Metrics Collection

If using InfluxDB as output:

```bash
# Connect to InfluxDB
influx -host <influxdb-host> -port 8086

# Check databases
SHOW DATABASES

# Use telegraf database
USE telegraf

# Show measurements
SHOW MEASUREMENTS

# Query recent data
SELECT * FROM cpu WHERE time > now() - 5m LIMIT 10
```

## Architecture

```
┌──────────────┐
│   config     │ ──> Pulls from Git (once)
└──────────────┘
       │
       ▼
┌──────────────┐
│agent (node1) │ ──┐
└──────────────┘   │
┌──────────────┐   │
│agent (node2) │ ──┼──> Output (InfluxDB, etc.)
└──────────────┘   │
┌──────────────┐   │
│agent (node3) │ ──┘
└──────────────┘
```

## Volumes

- `agent-config`: Telegraf configuration from Git (read-only)
- `/var/run/docker.sock`: Docker socket (bind mount, read-only)

## Global Deployment

The agent service uses `mode: global`, which means:
- One Telegraf instance runs on every swarm node
- Automatically deploys to new nodes when they join
- Each instance collects metrics from its host node

## Configuration Management

### Update Configuration

1. Update your Git repository with new Telegraf configuration
2. Force update the config service:

```bash
docker service update --force <stack>_config
```

3. Restart agent services to load new config:

```bash
docker service update --force <stack>_agent
```

### Test Configuration

Before committing to Git, test your configuration:

```bash
# Copy config to a test container
docker run --rm -v $(pwd)/telegraf.conf:/etc/telegraf/telegraf.conf telegraf:alpine telegraf --config /etc/telegraf/telegraf.conf --test
```

## Common Input Plugins

### System Metrics
```toml
[[inputs.cpu]]
[[inputs.disk]]
[[inputs.diskio]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.processes]]
[[inputs.system]]
```

### Docker Metrics
```toml
[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
```

### Log Monitoring
```toml
[[inputs.logparser]]
  files = ["/var/log/**.log"]
```

### HTTP Response Time
```toml
[[inputs.http_response]]
  urls = ["http://example.com"]
```

### SNMP
```toml
[[inputs.snmp]]
  agents = ["192.168.1.1"]
```

## Common Output Plugins

### InfluxDB
```toml
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "telegraf"
```

### Prometheus
```toml
[[outputs.prometheus_client]]
  listen = ":9273"
```

### Elasticsearch
```toml
[[outputs.elasticsearch]]
  urls = ["http://elasticsearch:9200"]
```

### File (for debugging)
```toml
[[outputs.file]]
  files = ["stdout"]
```

## Monitoring Docker Containers

This stack mounts the Docker socket, enabling container monitoring:

```toml
[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"

  # Gather container metrics
  gather_services = false

  # Timeout for docker operations
  timeout = "5s"

  # Include specific containers
  container_name_include = ["*"]

  # Exclude containers
  container_name_exclude = ["telegraf*"]

  # Collect per-device metrics
  perdevice = true
  total = false
```

## Security Considerations

1. **Git Access**: Ensure SSH key has read-only access to config repository
2. **Docker Socket**: Mounting Docker socket gives Telegraf significant access to the host
3. **Credentials**: Store sensitive credentials securely (use Docker secrets)
4. **Output Security**: Use TLS when sending metrics to remote systems
5. **Network Isolation**: Consider running on a monitoring-specific network

## Performance Tuning

### Adjust Collection Interval

```toml
[agent]
  interval = "60s"  # Collect every 60 seconds instead of 10s
```

### Limit Buffer Size

```toml
[agent]
  metric_buffer_limit = 5000  # Reduce memory usage
```

### Reduce Plugin Scope

Disable unnecessary inputs or limit collection:

```toml
[[inputs.disk]]
  # Only monitor specific mount points
  mount_points = ["/", "/data"]
```

## Troubleshooting

### Telegraf Not Collecting Metrics

1. Check Telegraf is running: `docker service ps <stack>_agent`
2. View logs: `docker service logs <stack>_agent`
3. Test configuration: `telegraf --test --config /etc/telegraf/telegraf.conf`
4. Verify input plugins are configured correctly

### Cannot Connect to Output

1. Check network connectivity to output destination
2. Verify credentials are correct
3. Check output plugin logs in Telegraf logs
4. Test connectivity: `telnet <output-host> <port>`

### High Memory Usage

1. Reduce `metric_buffer_limit`
2. Increase `flush_interval`
3. Disable unnecessary input plugins
4. Reduce collection interval

### Configuration Not Updating

1. Verify Git repository is accessible
2. Check config service logs: `docker service logs <stack>_config`
3. Verify SSH key secret is correct
4. Force update: `docker service update --force <stack>_config`

### Docker Socket Permission Denied

Ensure the Docker socket is properly mounted:
```yaml
volumes:
  - type: bind
    source: /var/run/docker.sock
    target: /var/run/docker.sock
```

## Integration with InfluxDB and Grafana

### 1. Deploy InfluxDB

Use the InfluxDB stack in this repository.

### 2. Configure Telegraf Output

```toml
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "telegraf"
  username = "telegraf"
  password = "your_password"
```

### 3. Deploy Grafana

Use the Grafana stack in this repository.

### 4. Add InfluxDB Data Source in Grafana

- URL: `http://influxdb:8086`
- Database: `telegraf`
- User: `telegraf`
- Password: `your_password`

### 5. Import Telegraf Dashboards

Grafana has pre-built dashboards for Telegraf metrics.

## Maintenance

### Regular Tasks

- Review and optimize configuration monthly
- Check for plugin updates
- Monitor disk usage of output destination
- Verify all nodes are reporting metrics

### Updates

```bash
# Pull latest image
docker service update --image telegraf:alpine <stack>_agent
```

## Documentation

- [Telegraf Documentation](https://docs.influxdata.com/telegraf/)
- [Input Plugins](https://docs.influxdata.com/telegraf/latest/plugins/#input-plugins)
- [Output Plugins](https://docs.influxdata.com/telegraf/latest/plugins/#output-plugins)
- [Configuration Guide](https://docs.influxdata.com/telegraf/latest/administration/configuration/)

## Quick Reference

```bash
# View all agent instances
docker service ps <stack>_agent

# View logs
docker service logs <stack>_agent

# Update configuration
docker service update --force <stack>_config
docker service update --force <stack>_agent

# Test configuration
docker exec <container> telegraf --test

# Check status
docker service ls | grep telegraf
```
