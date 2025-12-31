# Unbound DNS Stack

This stack deploys Unbound, a validating, recursive, and caching DNS resolver with additional features including DNS-based ad blocking.

## Prerequisites

- Docker Swarm environment
- Git repository containing Unbound configuration
- SSH key for accessing the Git configuration repository
- Port 53 available (both TCP and UDP)

## Required Environment Variables

Configure these before deployment:

### DNS Configuration
- `DNS_PORT`: Port for DNS service (default: `53`)

### Git Configuration Repository
- `CONFIG_REPO`: **Required** - URL of the Git repository containing Unbound configuration files
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

Create a Git repository with Unbound configuration files. Example structure:

```
unbound-config/
├── conf.d/
│   └── server.conf
└── server-conf.d/
    └── custom-hosts.conf
```

Example `server.conf`:
```conf
server:
    verbosity: 1
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 0.0.0.0/0 allow
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    hide-identity: yes
    hide-version: yes
```

## Services Included

### server
- Main Unbound DNS resolver
- Validating and caching recursive DNS
- Uses configuration from Git repository

### config
- Pulls Unbound configuration from Git repository
- Runs once at startup
- Mounts configuration read-only to server

### root-hints
- Periodically downloads root DNS server hints
- Runs monthly (Rancher schedule)
- Updates `/data/root.hints` file

### hosts
- Downloads ad-blocking host lists
- Generates blackhole configuration
- Uses StevenBlack's unified hosts file
- Runs monthly to update block lists

### monitor
- Watches for configuration changes
- Automatically reloads Unbound when changes detected
- Checks daily for changes with 1-minute delay

## Post-Deployment Configuration

### 1. Verify DNS Resolution

Test DNS resolution:

```bash
# Test against your Unbound server
dig @<server-ip> google.com
nslookup google.com <server-ip>

# Test DNSSEC validation
dig @<server-ip> dnssec-failed.org +dnssec
```

### 2. Configure Clients

Update DNS settings on client devices:
- Primary DNS: `<server-ip>`
- Secondary DNS: `<backup-dns>`

### 3. Test Ad Blocking

Test that ad domains are blocked:

```bash
dig @<server-ip> ads.example.com
dig @<server-ip> doubleclick.net
```

Blocked domains should return `0.0.0.0` or refuse to resolve.

## Architecture

```
┌──────────────┐
│   config     │ ──> Pulls from Git (once)
└──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│   server     │ ◄── │   monitor    │ (watches for changes)
└──────────────┘     └──────────────┘
       ▲
       │
       ├─── server-config (from Git)
       ├─── server-hints (root DNS servers)
       └─── server-hosts (ad-blocking rules)
```

## Volumes

- `server-config`: Unbound configuration from Git (read-only)
- `server-hints`: Root DNS server hints (read-write)
- `server-hosts`: DNS blackhole/ad-blocking rules (read-only)

## Ports Exposed

- `53/tcp`: DNS over TCP
- `53/udp`: DNS over UDP

## Ad Blocking

This stack uses DNS-based ad blocking via the `hosts` service:

### Default Block Lists

- **StevenBlack's Unified Hosts**: Comprehensive ad/malware/tracking blocking

### Custom Block Lists

Add custom block lists by modifying the `hosts` service environment:

```yaml
environment:
  DNSBH_HOSTS_StevenBlack: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
  DNSBH_HOSTS_Custom: https://your-custom-blocklist-url
```

### Whitelist Domains

Add to your Unbound configuration in Git repository:

```conf
server:
    local-zone: "example.com" transparent
```

## Configuration Management

### Update Configuration

1. Update your Git repository with new Unbound configuration
2. The `monitor` service checks for changes daily
3. Unbound automatically reloads when changes detected

For immediate reload:
```bash
docker service update --force <stack>_config
```

### Manual Reload

Force Unbound to reload configuration:

```bash
docker exec <unbound_container> kill -HUP 1
```

## Security Considerations

1. **Access Control**: Configure `access-control` in Unbound config to restrict queries
2. **DNSSEC**: Enable DNSSEC validation for security
3. **Git Access**: Ensure SSH key has read-only access to config repository
4. **Rate Limiting**: Configure rate limiting to prevent DNS amplification attacks
5. **Private Networks**: Only expose to trusted networks

Example access control:
```conf
server:
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse
```

## Performance Tuning

### Cache Configuration

```conf
server:
    msg-cache-size: 128m
    rrset-cache-size: 256m
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
```

### Thread Configuration

```conf
server:
    num-threads: 2
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2
```

## Monitoring

### Check DNS Performance

```bash
# Query statistics
docker exec <container> unbound-control stats

# Check cache hit rate
docker exec <container> unbound-control stats_noreset | grep cache
```

### View Logs

```bash
docker service logs <stack>_server
```

### Check Block List Status

```bash
docker service logs <stack>_hosts
```

## Troubleshooting

### DNS Not Resolving

1. Check Unbound is running: `docker service ps <stack>_server`
2. Verify port 53 is accessible: `telnet <server-ip> 53`
3. Check Unbound logs: `docker service logs <stack>_server`
4. Test local resolution: `docker exec <container> unbound-control status`

### Configuration Not Updating

1. Verify Git repository is accessible
2. Check config service logs: `docker service logs <stack>_config`
3. Verify SSH key secret is correct
4. Check monitor service: `docker service logs <stack>_monitor`

### Ad Blocking Not Working

1. Check hosts service ran successfully: `docker service logs <stack>_hosts`
2. Verify blackhole.conf was created
3. Check server-hosts volume is mounted
4. Test domain: `dig @<server-ip> ads.google.com`

### DNSSEC Validation Failing

1. Ensure root hints are up to date
2. Check `root-hints` service: `docker service logs <stack>_root-hints`
3. Verify system clock is accurate (DNSSEC requires accurate time)
4. Test: `dig @<server-ip> . DNSKEY +dnssec`

### High CPU Usage

1. Reduce cache sizes
2. Decrease num-threads
3. Implement rate limiting
4. Check for DNS amplification attacks

## Maintenance

### Monthly Tasks (Automated)

- Root hints update (via `root-hints` service)
- Block list update (via `hosts` service)

### Manual Tasks

- Review Unbound logs for errors
- Update Unbound configuration as needed
- Test DNSSEC validation periodically
- Monitor query performance

## Documentation

- [Unbound Documentation](https://unbound.docs.nlnetlabs.nl/)
- [Unbound Configuration Reference](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html)
- [DNSSEC Guide](https://unbound.docs.nlnetlabs.nl/en/latest/topics/dnssec/dnssec.html)
- [StevenBlack Hosts](https://github.com/StevenBlack/hosts)

## Quick Reference

```bash
# Test DNS resolution
dig @<server-ip> example.com

# Check Unbound status
docker exec <container> unbound-control status

# View statistics
docker exec <container> unbound-control stats

# Reload configuration
docker exec <container> kill -HUP 1

# Flush cache
docker exec <container> unbound-control flush_zone .

# View logs
docker service logs <stack>_server
```
