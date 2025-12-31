# CockroachDB Stack

This stack deploys an **insecure** CockroachDB cluster for development and testing purposes.

## Important Security Warning

⚠️ **This deployment is INSECURE and NOT suitable for production use!**

This stack runs CockroachDB with the `--insecure` flag, which means:
- No authentication required
- No encryption in transit
- No user management
- Anyone with network access can read/write data

For production deployments, please refer to the [official CockroachDB documentation](https://www.cockroachlabs.com/docs/stable/orchestrate-cockroachdb-with-docker-swarm.html).

## Prerequisites

- Docker Swarm environment
- Multiple nodes recommended for proper cluster operation

## Architecture

This stack creates:
- **roach1**: A single CockroachDB node (leader)
- **roachN**: Additional CockroachDB nodes deployed globally across all swarm nodes

## Services

### roach1
- Single replica leader node
- Exposes web UI on port 8080
- Other nodes join this node

### roachN
- Globally deployed (one instance per swarm node)
- Joins the cluster via roach1
- Automatically discovers and connects to other nodes

## Post-Deployment Configuration

### 1. Access the Web UI

The CockroachDB admin UI is available at:
- URL: `http://<swarm-node-ip>:8080`

Since port 8080 is exposed randomly, find the actual port:
```bash
docker service ls
docker service ps <stack>_roach1
```

### 2. Initialize the Database

Connect to one of the nodes to create databases and tables:

```bash
# Get container ID
docker ps | grep cockroach

# Connect to SQL shell
docker exec -it <container_id> ./cockroach sql --insecure

# Or from outside the container
docker exec -it <container_id> ./cockroach sql --insecure --host=roach1
```

### 3. Create a Database

```sql
CREATE DATABASE mydb;
SHOW DATABASES;
USE mydb;
```

### 4. Create Tables and Insert Data

```sql
CREATE TABLE users (
    id INT PRIMARY KEY,
    name STRING,
    email STRING
);

INSERT INTO users VALUES (1, 'Alice', 'alice@example.com');
SELECT * FROM users;
```

## Cluster Management

### Check Cluster Status

```bash
docker exec <container_id> ./cockroach node status --insecure
```

### View Node Information

In the SQL shell:
```sql
SHOW NODES;
```

### Scale the Cluster

The `roachN` service is deployed globally, so it automatically scales with your swarm:
- Add a new swarm node → CockroachDB automatically deploys there
- Remove a swarm node → CockroachDB rebalances data

To manually scale:
```bash
docker service scale <stack>_roachN=<number>
```

## Connecting Applications

Applications can connect to any node in the cluster:

**Connection String Example:**
```
postgresql://root@roach1:26257/mydb?sslmode=disable
```

**Node Endpoints:**
- `roach1:26257` - Leader node
- `roachN:26257` - Global nodes (load balanced)

## Ports

- **26257**: CockroachDB SQL interface (internal)
- **8080**: Web UI (randomly mapped externally)

## Volumes

This insecure deployment does not define persistent volumes. Data is lost when containers are removed.

For production with persistence, add volumes:
```yaml
volumes:
  - cockroach-data:/cockroach/cockroach-data
```

## Performance Tuning

### For Development

This default configuration is fine for development and testing.

### For Production

Refer to the official documentation for:
- Security configurations (TLS, authentication)
- Resource limits (CPU, memory)
- Persistent volumes
- Backup and restore procedures
- High availability configurations

## Monitoring

### Web UI Metrics

Access the web UI to view:
- Cluster health
- Node status
- Query performance
- Storage metrics

### Command Line

```bash
# Check node status
docker exec <container_id> ./cockroach node status --insecure

# View cluster metrics
docker exec <container_id> ./cockroach node ls --insecure
```

## Backup and Restore

### Backup a Database

```bash
docker exec <container_id> ./cockroach dump mydb --insecure > backup.sql
```

### Restore a Database

```bash
cat backup.sql | docker exec -i <container_id> ./cockroach sql --insecure
```

## Troubleshooting

### Node Won't Join Cluster

1. Check network connectivity between nodes
2. Verify `roach1` is running: `docker service ps <stack>_roach1`
3. Check logs: `docker service logs <stack>_roachN`
4. Ensure swarm overlay network is functioning

### Cannot Access Web UI

1. Find the published port: `docker service ps <stack>_roach1`
2. Ensure no firewall is blocking port 8080
3. Try accessing via different swarm node IPs

### Data Loss After Restart

This is expected with the default configuration (no persistent volumes). Add volumes for data persistence.

### Cluster Performance Issues

1. Check node resources (CPU, memory)
2. Review query performance in web UI
3. Check for under-replicated ranges
4. Ensure sufficient nodes for replication factor

## Migration to Production

To convert this to a production-ready deployment:

1. **Remove `--insecure` flag**
2. **Add TLS certificates**
3. **Configure authentication**
4. **Add persistent volumes**
5. **Set resource limits**
6. **Configure backups**
7. **Set up monitoring and alerting**

Example secure configuration:
```yaml
command: "start --certs-dir=/certs --join=roach1,roach2,roach3"
```

## Documentation

- [CockroachDB Documentation](https://www.cockroachlabs.com/docs/stable/)
- [Docker Swarm Deployment Guide](https://www.cockroachlabs.com/docs/stable/orchestrate-cockroachdb-with-docker-swarm.html)
- [CockroachDB SQL Reference](https://www.cockroachlabs.com/docs/stable/sql-statements.html)
- [Production Checklist](https://www.cockroachlabs.com/docs/stable/recommended-production-settings.html)

## Quick Reference

```bash
# SQL Shell
docker exec -it <container_id> ./cockroach sql --insecure

# Node Status
docker exec <container_id> ./cockroach node status --insecure

# Cluster Status
docker exec <container_id> ./cockroach node ls --insecure

# Create Database
docker exec <container_id> ./cockroach sql --insecure -e "CREATE DATABASE mydb;"

# Backup
docker exec <container_id> ./cockroach dump mydb --insecure > backup.sql

# View Logs
docker service logs <stack>_roach1
docker service logs <stack>_roachN
```
