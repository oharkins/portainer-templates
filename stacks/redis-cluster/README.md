# Redis Cluster Stack

This stack deploys a 3-node Redis Cluster using Bitnami's Redis Cluster image, providing high availability and automatic sharding for your caching and data storage needs.

## Overview

Redis Cluster provides:
- **High Availability**: Automatic failover and replication
- **Data Sharding**: Automatic data distribution across nodes
- **Scalability**: Horizontal scaling by adding nodes
- **Performance**: In-memory data structure store

Perfect for:
- Session storage for web applications
- Caching layer for databases
- Message broker for microservices
- Real-time analytics
- Rate limiting
- Pub/sub messaging
- Home automation state management

## Prerequisites

- Docker Compose or Docker Swarm environment
- At least 3 nodes recommended for production
- Sufficient memory for Redis workload

## Required Environment Variables

- `REDIS_PASSWD`: Password for Redis authentication

## Architecture

This stack creates a 3-node Redis cluster:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ redis-node-0 │────▶│ redis-node-1 │────▶│ redis-node-2 │
│  (Leader)    │     │   (Member)   │     │  (Creator)   │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
  [Data Shard 1]      [Data Shard 2]      [Data Shard 3]
```

## Services

### redis-node-0
- First cluster node
- Other nodes connect to this

### redis-node-1
- Second cluster node
- Replicates data

### redis-node-2
- Third cluster node
- Cluster creator (initializes the cluster)
- No replicas (REDIS_CLUSTER_REPLICAS=0)

## Pre-Deployment Setup

### 1. Set Redis Password

```bash
# Generate a strong password
export REDIS_PASSWD=$(openssl rand -base64 32)

# Or set manually
export REDIS_PASSWD="your_secure_password_here"
```

**Important**: Use a strong password! Redis is fast and vulnerable to brute force.

## Post-Deployment Configuration

### 1. Verify Cluster is Running

```bash
docker-compose ps

# All three nodes should show as "Up"
```

### 2. Check Cluster Status

```bash
# Connect to any node
docker exec -it <container-id> redis-cli -c -a ${REDIS_PASSWD}

# Check cluster info
CLUSTER INFO

# View cluster nodes
CLUSTER NODES

# Expected output shows 3 nodes, all connected
```

### 3. Test Cluster

```bash
# Set a key
redis-cli -c -a ${REDIS_PASSWD} SET mykey "Hello Redis Cluster"

# Get the key
redis-cli -c -a ${REDIS_PASSWD} GET mykey

# Check where key is stored
redis-cli -c -a ${REDIS_PASSWD} CLUSTER KEYSLOT mykey
```

## Connecting to Redis Cluster

### Connection String

```
redis://:<password>@redis-node-0:6379,redis-node-1:6379,redis-node-2:6379
```

### From Docker Containers (Same Network)

```bash
# Python example
import redis
from redis.cluster import RedisCluster

rc = RedisCluster(
    startup_nodes=[
        {"host": "redis-node-0", "port": 6379},
        {"host": "redis-node-1", "port": 6379},
        {"host": "redis-node-2", "port": 6379}
    ],
    password="your_password",
    decode_responses=True
)

rc.set("foo", "bar")
print(rc.get("foo"))
```

### Node.js Example

```javascript
const Redis = require('ioredis');

const cluster = new Redis.Cluster([
  { host: 'redis-node-0', port: 6379 },
  { host: 'redis-node-1', port: 6379 },
  { host: 'redis-node-2', port: 6379 }
], {
  redisOptions: {
    password: 'your_password'
  }
});

cluster.set('foo', 'bar');
cluster.get('foo', (err, result) => {
  console.log(result);
});
```

## Home Automation Use Cases

### 1. State Management

Store home automation state:

```python
# Home Assistant state caching
rc.set("sensor.living_room_temp", "22.5")
rc.expire("sensor.living_room_temp", 3600)  # 1 hour TTL

# Get current state
temp = rc.get("sensor.living_room_temp")
```

### 2. Event Queue

```python
# Queue automation events
rc.lpush("automation:queue", json.dumps({
    "event": "motion_detected",
    "location": "front_door",
    "timestamp": time.time()
}))

# Process events
event = rc.rpop("automation:queue")
```

### 3. Rate Limiting

```python
# Limit API calls
def rate_limit(user_id, limit=10, window=60):
    key = f"rate_limit:{user_id}"
    current = rc.incr(key)
    if current == 1:
        rc.expire(key, window)
    return current <= limit
```

### 4. Session Storage

```python
# Store user sessions
rc.setex(f"session:{session_id}", 3600, json.dumps(session_data))

# Retrieve session
session_data = json.loads(rc.get(f"session:{session_id}"))
```

### 5. Pub/Sub Messaging

```python
# Publish events
rc.publish("home/motion", "front_door")

# Subscribe to events
pubsub = rc.pubsub()
pubsub.subscribe("home/motion")
for message in pubsub.listen():
    print(message)
```

### 6. Caching Database Queries

```python
# Cache expensive queries
def get_device_status(device_id):
    cache_key = f"device:{device_id}:status"
    cached = rc.get(cache_key)

    if cached:
        return json.loads(cached)

    # Query database
    status = db.query_device_status(device_id)

    # Cache for 5 minutes
    rc.setex(cache_key, 300, json.dumps(status))
    return status
```

## Scaling the Cluster

### Add More Nodes

To add more nodes:

1. Add new service to docker-compose:

```yaml
redis-node-3:
  image: docker.io/bitnami/redis-cluster:6.2
  volumes:
    - redis-cluster_data-3:/bitnami/redis/data
  environment:
    - "REDIS_PASSWORD=${REDIS_PASSWD}"
    - "REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3"
```

2. Add the node to cluster:

```bash
redis-cli -c -a ${REDIS_PASSWD} --cluster add-node redis-node-3:6379 redis-node-0:6379
```

3. Rebalance cluster:

```bash
redis-cli -c -a ${REDIS_PASSWD} --cluster rebalance redis-node-0:6379
```

## Cluster Management

### View Cluster Info

```bash
# Connect to cluster
redis-cli -c -h redis-node-0 -a ${REDIS_PASSWD}

# Cluster information
CLUSTER INFO

# Node details
CLUSTER NODES

# Slot distribution
CLUSTER SLOTS
```

### Rebalance Cluster

```bash
redis-cli -c -a ${REDIS_PASSWD} --cluster rebalance redis-node-0:6379 \
  --cluster-use-empty-masters
```

### Check Cluster Health

```bash
redis-cli -c -a ${REDIS_PASSWD} --cluster check redis-node-0:6379
```

### Fix Cluster Issues

```bash
redis-cli -c -a ${REDIS_PASSWD} --cluster fix redis-node-0:6379
```

## Monitoring

### Key Metrics to Monitor

```bash
# Memory usage
INFO memory

# Connected clients
INFO clients

# Operations per second
INFO stats

# Hit rate
INFO stats | grep keyspace
```

### Monitor with Redis CLI

```bash
# Real-time monitoring
redis-cli -c -a ${REDIS_PASSWD} --stat

# Monitor commands
redis-cli -c -a ${REDIS_PASSWD} MONITOR
```

### Prometheus Monitoring

Use Redis Exporter:

```yaml
redis-exporter:
  image: oliver006/redis_exporter
  environment:
    - REDIS_ADDR=redis-node-0:6379
    - REDIS_PASSWORD=${REDIS_PASSWD}
  ports:
    - "9121:9121"
```

## Backup and Restore

### Manual Backup

```bash
# Trigger background save
redis-cli -c -a ${REDIS_PASSWD} BGSAVE

# Wait for completion
redis-cli -c -a ${REDIS_PASSWD} LASTSAVE

# Copy RDB files from volumes
docker cp <container>:/bitnami/redis/data/dump.rdb ./backup/
```

### Automated Backup

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)

# Trigger save on all nodes
for node in redis-node-0 redis-node-1 redis-node-2; do
    docker exec $node redis-cli -a ${REDIS_PASSWD} BGSAVE
done

# Wait and copy backups
sleep 10
for node in redis-node-0 redis-node-1 redis-node-2; do
    docker cp $node:/bitnami/redis/data/dump.rdb ./backup/${node}_${DATE}.rdb
done
```

### Restore from Backup

1. Stop cluster
2. Copy RDB file to data volume
3. Start cluster

```bash
docker-compose down
docker cp backup.rdb <volume-path>/dump.rdb
docker-compose up -d
```

## Performance Tuning

### Memory Management

```bash
# Set max memory (in container environment)
REDIS_MAXMEMORY=2gb

# Set eviction policy
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

### Persistence Options

**RDB (snapshot)**:
- Fast, compact backups
- Point-in-time recovery
- May lose data in crash

**AOF (append-only file)**:
- Better durability
- Larger files
- Slower performance

```yaml
environment:
  - REDIS_AOF_ENABLED=no  # Default: RDB only
```

### Connection Pool

Always use connection pooling:

```python
# Python example
pool = redis.ConnectionPool(
    host='redis-node-0',
    port=6379,
    password='your_password',
    max_connections=50
)
rc = redis.Redis(connection_pool=pool)
```

## Security Considerations

1. **Strong Password**: Use complex passwords (min 32 characters)
2. **Network Isolation**: Don't expose Redis to internet
3. **Encryption**: Use TLS for production (requires configuration)
4. **Rename Commands**: Disable dangerous commands
5. **Firewall**: Restrict access to known IPs
6. **Regular Updates**: Keep Redis updated
7. **Memory Limits**: Set maxmemory to prevent OOM

### Disable Dangerous Commands

```yaml
environment:
  - REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL,KEYS,CONFIG
```

## Troubleshooting

### Cluster Won't Form

1. **Check logs**: `docker-compose logs redis-node-2`
2. **Verify network**: All nodes must communicate
3. **Check passwords**: Must match on all nodes
4. **Wait longer**: Cluster formation can take 30-60 seconds

### Node Shows as Disconnected

```bash
# Check node status
redis-cli -c -a ${REDIS_PASSWD} CLUSTER NODES

# Rejoin node
redis-cli -c -a ${REDIS_PASSWD} CLUSTER MEET redis-node-1 6379
```

### High Memory Usage

```bash
# Check memory
redis-cli -a ${REDIS_PASSWD} INFO memory

# Find big keys
redis-cli -a ${REDIS_PASSWD} --bigkeys

# Set memory limit
redis-cli -a ${REDIS_PASSWD} CONFIG SET maxmemory 2gb
redis-cli -a ${REDIS_PASSWD} CONFIG SET maxmemory-policy allkeys-lru
```

### Slow Performance

1. **Check slow log**:
   ```bash
   redis-cli -a ${REDIS_PASSWD} SLOWLOG GET 10
   ```

2. **Avoid KEYS command**: Use SCAN instead
3. **Use pipelining**: Batch commands
4. **Check network latency**: Between nodes and clients

### Connection Refused

1. Verify password is correct
2. Check node is running: `docker ps`
3. Verify network connectivity
4. Check firewall rules

## Best Practices

### 1. Use Connection Pooling

Always pool connections to reduce overhead.

### 2. Set Expiration Times

```python
# Always set TTL for cached data
rc.setex("key", 3600, "value")  # 1 hour
```

### 3. Use Appropriate Data Structures

- **Strings**: Simple key-value
- **Hashes**: Objects with fields
- **Lists**: Queues, stacks
- **Sets**: Unique items
- **Sorted Sets**: Leaderboards, rankings

### 4. Avoid Large Keys

Split large data into smaller keys:

```python
# Bad: One huge key
rc.set("all_sensors", huge_json)

# Good: Many small keys
for sensor in sensors:
    rc.set(f"sensor:{sensor.id}", sensor.data)
```

### 5. Monitor Memory Usage

Set up alerts for:
- Memory usage > 80%
- Evicted keys > threshold
- Connection count

### 6. Regular Backups

Automate backups with scheduler stack:
- Daily RDB snapshots
- Weekly full backups
- Test restores monthly

## Integration Examples

### Home Assistant

```yaml
# configuration.yaml
recorder:
  db_url: redis://:<password>@redis-node-0:6379/0
```

### n8n Workflow Cache

```javascript
const cache = new Redis.Cluster([
  {host: 'redis-node-0', port: 6379}
], {
  redisOptions: {password: process.env.REDIS_PASSWORD}
});

// Cache workflow results
await cache.set(`workflow:${id}`, JSON.stringify(result), 'EX', 3600);
```

### API Rate Limiting

```python
@app.before_request
def rate_limit():
    ip = request.remote_addr
    key = f"rate:{ip}"

    requests = rc.incr(key)
    if requests == 1:
        rc.expire(key, 60)

    if requests > 100:
        abort(429)  # Too many requests
```

## Maintenance

### Regular Tasks

- **Daily**: Check memory usage and evictions
- **Weekly**: Review slow log
- **Monthly**: Test backup restore
- **Quarterly**: Update Redis version

### Cleanup

```bash
# Remove expired keys (automatic, but can force)
redis-cli -a ${REDIS_PASSWD} BGREWRITEAOF
```

## Volumes

- `redis-cluster_data-0`: Node 0 data persistence
- `redis-cluster_data-1`: Node 1 data persistence
- `redis-cluster_data-2`: Node 2 data persistence

## Documentation

- [Redis Cluster Documentation](https://redis.io/docs/management/scaling/)
- [Redis Commands Reference](https://redis.io/commands/)
- [Bitnami Redis Cluster](https://github.com/bitnami/containers/tree/main/bitnami/redis-cluster)

## Quick Reference

```bash
# Connect to cluster
redis-cli -c -h redis-node-0 -a ${REDIS_PASSWD}

# Cluster info
CLUSTER INFO
CLUSTER NODES

# Set/Get key
SET mykey "value"
GET mykey

# List all keys (WARNING: slow on large datasets)
SCAN 0 MATCH * COUNT 100

# Monitor commands
MONITOR

# Check memory
INFO memory

# Slow queries
SLOWLOG GET 10

# Backup
BGSAVE
LASTSAVE

# Flush all data (DANGEROUS!)
FLUSHALL

# Monitor stats
redis-cli -c -a ${REDIS_PASSWD} --stat

# Big keys analysis
redis-cli -a ${REDIS_PASSWD} --bigkeys
```
