# Grafana Stack Configuration

This stack deploys Grafana with MySQL for persistence and Redis for session management.

## Prerequisites

- Docker Swarm environment
- Git repository containing Grafana configuration
- SSH key for accessing the Git configuration repository

## Required Environment Variables

Before deploying this stack, configure the following:

### Grafana Configuration
- `GRAFANA_PORT`: Port to expose Grafana (default: `3000`)
- `ADMIN_USER`: Grafana admin username (default: `grafana`)
- `ADMIN_PASSWORD`: Grafana admin password (default: `grafana`)

### Database Configuration
- `PERSISTENCE_PASSWORD`: Password for MySQL database (default: `grafana`)

### Git Configuration Repository
- `CONFIG_REPO`: **Required** - URL of the Git repository containing Grafana configuration
- `CONFIG_BRANCH`: Git branch to use (default: `master`)
- `GIT_USER`: Git username (default: `git`)

### Docker Secrets
- `GIT_KEY`: Name of the Docker secret containing SSH key for Git access (default: `git_reader_key`)

## Pre-Deployment Setup

### 1. Create Docker Secret for Git Access

Create a Docker secret containing your SSH private key:

```bash
# Create the secret from a file
docker secret create git_reader_key ~/.ssh/id_rsa

# Or if using a different key name, update the GIT_KEY variable
docker secret create config_reader_key /path/to/your/ssh/key
```

### 2. Prepare Configuration Repository

Ensure your Git repository contains Grafana configuration files that will be mounted to `/etc/grafana`. The repository structure should match Grafana's expected configuration layout.

## Post-Deployment Configuration

### 1. Access Grafana

Once deployed, access Grafana at:
- URL: `http://<your-server-ip>:${GRAFANA_PORT}`
- Default URL: `http://<your-server-ip>:3000`

### 2. First Login

Use the credentials specified in environment variables:
- Username: `${ADMIN_USER}` (default: `grafana`)
- Password: `${ADMIN_PASSWORD}` (default: `grafana`)

**Important**: Change the default admin password immediately after first login.

### 3. Verify Database Connection

Grafana should automatically connect to the MySQL database. Check:
1. Navigate to Configuration > Data Sources
2. Verify the MySQL connection is established

## Services Included

- **Grafana Server**: Visualization and analytics platform
- **Config Service**: Fetches configuration from Git repository (runs once at startup)
- **MySQL (MariaDB)**: Database for storing dashboards, users, and other data
- **Redis**: Session storage for improved performance

## Architecture

```
┌─────────────┐
│   Grafana   │ ──┐
└─────────────┘   │
                  ├──> MySQL (persistence)
┌─────────────┐   │
│   Config    │ ──┘
│   (Git)     │
└─────────────┘

┌─────────────┐
│   Redis     │ ──> Session Storage
└─────────────┘
```

## Volumes

The stack creates the following named volumes:
- `server-config`: Grafana configuration from Git
- `server-data`: Grafana data (dashboards, plugins, etc.)
- `sessions-data`: Redis session data
- `persistence-data`: MySQL database files

## Networks

- `persistence`: Communication between Grafana and MySQL
- `sessions`: Communication between Grafana and Redis

## Security Considerations

1. **Change Default Passwords**: Update `ADMIN_PASSWORD` and `PERSISTENCE_PASSWORD`
2. **Secure Git Access**: Ensure SSH key has read-only access to configuration repo
3. **Use Strong Passwords**: MySQL password should be complex
4. **Restrict Access**: Consider using a reverse proxy with HTTPS
5. **Backup Volumes**: Regularly backup the `server-data` and `persistence-data` volumes

## Configuration Management

The stack uses a Git-based configuration approach:
- Configuration is pulled from `CONFIG_REPO` at startup
- The config service runs once and then stops
- Configuration is mounted as read-only to Grafana
- To update configuration:
  1. Update your Git repository
  2. Redeploy the stack or restart the config service

## Troubleshooting

### Config Service Fails
If the config service cannot pull from Git:
1. Verify `CONFIG_REPO` URL is correct
2. Check SSH key is properly configured as a Docker secret
3. Ensure the Git repository is accessible
4. Check logs: `docker service logs <stack>_config`

### Database Connection Issues
If Grafana cannot connect to MySQL:
1. Wait a few minutes for MySQL to initialize
2. Check MySQL logs: `docker service logs <stack>_persistence`
3. Verify `PERSISTENCE_PASSWORD` matches in both services

### Session Issues
If experiencing login/session problems:
1. Check Redis is running: `docker service ps <stack>_sessions`
2. Verify Redis logs: `docker service logs <stack>_sessions`

## Default Credentials

**Change these immediately after deployment!**

- Grafana Admin: `admin` / `admin` (or your configured values)
- MySQL User: `grafana` / `grafana` (or your configured PERSISTENCE_PASSWORD)
- MySQL Database: `grafana`

## Documentation

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [MySQL Backend](https://grafana.com/docs/grafana/latest/setup-grafana/configure-database/)
