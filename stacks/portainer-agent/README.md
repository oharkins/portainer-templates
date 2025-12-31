# Portainer Agent Stack

This stack deploys the Portainer Agent, which enables a Portainer instance to remotely manage Docker environments across multiple nodes in a Swarm cluster.

## Overview

The Portainer Agent is a lightweight agent that:
- Runs on each node in your Docker Swarm
- Provides secure communication with Portainer Server
- Enables management of containers, volumes, networks, and more
- Supports remote environment management
- Minimal resource footprint

Perfect for:
- Multi-site Docker management
- Edge computing deployments
- Home lab with multiple servers
- Remote Docker host management
- Distributed home automation infrastructure

## Prerequisites

- Docker Swarm environment
- Portainer Server instance (separate host or same cluster)
- Network connectivity between Portainer Server and agents
- Port 9001 available on all nodes

## Architecture

```
┌──────────────────┐
│ Portainer Server │
│  (Main Instance) │
└─────────┬────────┘
          │
          │ Port 9001
          │
    ┌─────┴──────┐
    │            │
┌───▼────┐  ┌───▼────┐  ┌────▼───┐
│ Agent  │  │ Agent  │  │ Agent  │
│ Node 1 │  │ Node 2 │  │ Node 3 │
└────────┘  └────────┘  └────────┘
```

## Service Configuration

### agent
- Deployed globally (one instance per swarm node)
- Exposes port 9001 in host mode
- Has access to Docker socket and volumes
- Linux nodes only (placement constraint)

## Deployment

### 1. Deploy Agent Stack

This agent stack should be deployed on your **Swarm cluster**, not on the Portainer server.

```bash
docker stack deploy -c docker-stack.yml portainer-agent
```

### 2. Verify Agents are Running

```bash
# Check agent on all nodes
docker service ps portainer_agent_agent

# Should show one agent per node
```

### 3. Test Agent Connectivity

```bash
# From Portainer server or any host
curl http://<node-ip>:9001/ping

# Should return: "Portainer agent"
```

## Adding Environment to Portainer

### 1. Access Portainer UI

Navigate to your Portainer server:
```
https://<portainer-server>:9443
```

### 2. Add New Environment

1. Go to **Environments** > **Add environment**
2. Select **Docker Swarm** or **Docker Standalone**
3. Choose **Agent** as environment type
4. Enter agent details:
   - **Name**: Meaningful name (e.g., "Home Lab Cluster")
   - **Agent URL**: `<node-ip>:9001` (any node in the swarm)
   - **Public IP**: Optional, for edge agent tunneling

5. Click **Connect**

### 3. Verify Connection

Once added, you should see:
- Cluster information
- List of nodes
- Running containers
- Available stacks

## Port Configuration

- **Port 9001**: Agent API communication (TCP)
  - Uses **host mode** for direct node communication
  - Required to be accessible from Portainer server

## Security Considerations

### 1. Network Security

**Firewall Rules**:
```bash
# Allow Portainer server IP only
iptables -A INPUT -p tcp --dport 9001 -s <portainer-server-ip> -j ACCEPT
iptables -A INPUT -p tcp --dport 9001 -j DROP
```

**Or use Docker network** (if on same host):
- Remove published ports
- Use overlay network with Portainer server

### 2. TLS/SSL

For production, enable TLS:

```yaml
services:
  agent:
    image: portainer/agent
    environment:
      AGENT_SECRET: ${AGENT_SECRET}  # Shared secret with Portainer
```

On Portainer server, configure agent with matching secret.

### 3. Docker Socket Security

The agent has full Docker access via the socket. Ensure:
- Only trusted networks can reach port 9001
- Regular security updates
- Monitor agent logs for suspicious activity

## Home Automation Use Cases

### Multi-Location Management

Manage Docker hosts across different locations:
- **Main house**: Primary automation hub
- **Garage**: Separate Docker host for outdoor cameras
- **Vacation home**: Remote property automation
- **Parents' house**: Support remote Docker deployments

### Edge Computing

Deploy agents on edge devices:
- **Raspberry Pi clusters**: Home automation controllers
- **NAS devices**: Media and backup servers
- **Mini PCs**: Dedicated service nodes
- **IoT gateways**: Zigbee, Z-Wave controllers

### Centralized Management

Single Portainer dashboard to manage:
- Home Assistant instances across locations
- Distributed camera systems
- Multi-site MQTT brokers
- Backup and monitoring services

## Advanced Configuration

### Custom Agent Port

Change default port 9001:

```yaml
ports:
  - target: 9001
    published: 9002  # Custom port
    protocol: tcp
    mode: host
```

Update Portainer environment to use new port.

### Agent with Shared Secret

Add authentication between agent and server:

```yaml
services:
  agent:
    image: portainer/agent
    environment:
      - AGENT_SECRET=${AGENT_SECRET}
```

Generate secret:
```bash
export AGENT_SECRET=$(openssl rand -base64 32)
```

Configure Portainer to use same secret when adding environment.

### Resource Limits

Limit agent resource usage:

```yaml
deploy:
  mode: global
  resources:
    limits:
      cpus: '0.5'
      memory: 128M
    reservations:
      memory: 64M
```

### Logging Configuration

Configure logging driver:

```yaml
services:
  agent:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Edge Agent Mode

For remote sites with no inbound connectivity:

### 1. Deploy Edge Agent

```yaml
services:
  agent:
    image: portainer/agent
    command: --edge --edge-id ${EDGE_ID}
    environment:
      - EDGE_KEY=${EDGE_KEY}
      - EDGE_ID=${EDGE_ID}
      - PORTAINER_URL=${PORTAINER_URL}
```

### 2. Configure in Portainer

1. Go to **Environments** > **Add environment**
2. Select **Edge Agent**
3. Configure edge settings
4. Copy deployment command
5. Run on remote host

### 3. Benefits

- **No inbound ports**: Agent polls Portainer
- **NAT/Firewall friendly**: Works behind restrictive networks
- **Intermittent connectivity**: Handles disconnections gracefully
- **Async operations**: Commands queued when offline

## Monitoring

### Check Agent Status

```bash
# View agent logs
docker service logs portainer_agent_agent

# Follow logs in real-time
docker service logs -f portainer_agent_agent

# Check specific node
docker service ps portainer_agent_agent --filter node=<node-name>
```

### Health Check

The agent doesn't have a built-in health check, but you can monitor:

```bash
# Check if port is listening
nc -zv <node-ip> 9001

# HTTP ping
curl http://<node-ip>:9001/ping

# Full status (requires auth)
curl -H "X-PortainerAgent-Token: ${TOKEN}" \
  http://<node-ip>:9001/info
```

## Troubleshooting

### Agent Not Accessible from Portainer

1. **Check agent is running**:
   ```bash
   docker service ps portainer_agent_agent
   ```

2. **Verify port 9001 is open**:
   ```bash
   netstat -tuln | grep 9001
   ```

3. **Test connectivity**:
   ```bash
   curl http://<agent-ip>:9001/ping
   ```

4. **Check firewall**:
   ```bash
   iptables -L -n | grep 9001
   ```

5. **Check Portainer logs** for connection errors

### Agent Shows as Disconnected

1. **Network issues**: Verify network connectivity
2. **Agent crashed**: Check logs for errors
3. **Version mismatch**: Ensure agent and Portainer versions are compatible
4. **Resource limits**: Check if agent is OOM killed

### Cannot Add Environment in Portainer

1. **Wrong URL**: Use `<ip>:9001` not `http://<ip>:9001`
2. **Port not accessible**: Test with curl
3. **TLS mismatch**: If Portainer uses TLS, agent URL might need `https://`
4. **Firewall**: Ensure Portainer server can reach agent port

### High Resource Usage

1. **Check logs** for errors or loops
2. **Limit resources** with deploy limits
3. **Monitor** with Prometheus or similar
4. **Update** to latest agent version

## Best Practices

### 1. Use Overlay Network (Same Cluster)

If Portainer server runs in same cluster:

```yaml
networks:
  portainer_agent:
    driver: overlay
    attachable: true
    internal: true  # No external access needed
```

Remove published ports for better security.

### 2. Enable Shared Secrets

Always use `AGENT_SECRET` in production:
```yaml
environment:
  - AGENT_SECRET=${AGENT_SECRET}
```

### 3. Restrict Access

Use firewall rules to limit access to Portainer server IP only.

### 4. Regular Updates

Keep agent updated with Portainer server:
```bash
docker service update --image portainer/agent:latest portainer_agent_agent
```

### 5. Monitor Logs

Regularly review agent logs for:
- Connection issues
- Authentication failures
- Resource errors

### 6. Label Environments

In Portainer, use meaningful names and tags:
- **Name**: "Home Lab - Main"
- **Group**: "Home Automation"
- **Tags**: production, swarm, raspberry-pi

## Integration with Home Automation

### Manage Remote Sites

```
Main Portainer Server (home.example.com)
├── Environment: Main House
│   ├── Home Assistant
│   ├── MQTT Broker
│   ├── Node-RED
│   └── Grafana
├── Environment: Garage
│   ├── Security Cameras
│   ├── Frigate NVR
│   └── Motion Detection
└── Environment: Remote Property
    ├── Home Assistant
    ├── Environment Sensors
    └── Backup Services
```

### Automate Deployments

Use Portainer API to deploy stacks programmatically:

```bash
# Deploy stack via API
curl -X POST "https://portainer.example.com/api/stacks" \
  -H "X-API-Key: ${PORTAINER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @stack.json
```

### Monitor Multiple Locations

Single dashboard showing:
- All containers across all sites
- Resource usage per location
- Container health status
- Stack deployment status

## Maintenance

### Update Agent

```bash
# Pull latest image
docker service update --image portainer/agent:latest portainer_agent_agent

# Or specific version
docker service update --image portainer/agent:2.19.4 portainer_agent_agent
```

### Restart Agent

```bash
docker service update --force portainer_agent_agent
```

### Remove Agent

```bash
# Remove stack
docker stack rm portainer_agent

# Or service
docker service rm portainer_agent_agent
```

## Volumes

The agent mounts:
- `/var/run/docker.sock`: Docker socket for API access
- `/var/lib/docker/volumes`: Access to volume data

These are read from the host, not persisted in named volumes.

## Networks

- `portainer_agent`: Overlay network for agent communication
  - **Driver**: overlay
  - **Attachable**: true (allows external containers to join)

## Performance Considerations

### Resource Usage

Typical agent resource usage:
- **CPU**: < 1% idle, 5-10% under load
- **Memory**: 50-100 MB
- **Network**: Minimal (only when Portainer queries)

### Scaling

- One agent per node (global mode)
- Lightweight enough for Raspberry Pi
- No horizontal scaling needed (stateless)

## Security Checklist

- [ ] Firewall configured to allow only Portainer server
- [ ] Using shared secret (`AGENT_SECRET`)
- [ ] Agents updated to latest version
- [ ] Logs monitored for suspicious activity
- [ ] Docker socket access understood and accepted
- [ ] Network segmented (internal overlay if possible)
- [ ] Using TLS for production deployments

## Documentation

- [Portainer Agent Documentation](https://docs.portainer.io/admin/environments/add/docker/agent)
- [Portainer API Documentation](https://docs.portainer.io/api/access)
- [Edge Agent Documentation](https://docs.portainer.io/admin/environments/add/docker/edge)

## Quick Reference

```bash
# Deploy agent stack
docker stack deploy -c docker-stack.yml portainer-agent

# Check agent status
docker service ps portainer_agent_agent

# View logs
docker service logs portainer_agent_agent

# Test agent connectivity
curl http://<node-ip>:9001/ping

# Update agent
docker service update --image portainer/agent:latest portainer_agent_agent

# Restart agent
docker service update --force portainer_agent_agent

# Remove agent
docker stack rm portainer-agent

# Check which nodes have agents
docker service ps portainer_agent_agent --format "table {{.Node}}\t{{.CurrentState}}"

# Generate agent secret
openssl rand -base64 32
```

## Common Agent URL Formats

```bash
# Standard agent
http://<node-ip>:9001

# Custom port
http://<node-ip>:9002

# TLS enabled
https://<node-ip>:9001

# Via load balancer
http://agents.example.com:9001
```

When adding to Portainer, use the URL **without** protocol prefix:
```
<node-ip>:9001
```
