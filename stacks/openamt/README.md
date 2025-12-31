# Open Active Management Technology (OpenAMT) Stack

This stack deploys the Intel Open AMT Cloud Toolkit for remote management of Intel AMT devices.

## Prerequisites

- Docker Compose environment
- Understanding of Intel AMT technology
- Network access to AMT devices

## Required Environment Variables

Configure these environment variables before deployment:

### MPS (Management Presence Server) Configuration
- `MPS_COMMON_NAME`: **Required** - The FQDN or IP address where the MPS server is accessible (e.g., `amt.example.com`)
- `MPS_USER`: Admin username for MPS web interface
- `MPS_PASSWORD`: **Must be 8-32 characters** including one uppercase, one lowercase, one digit, and one special character
- `MPS_SECRET`: JWT secret for authentication (generate with: `openssl rand -base64 32`)

### Database Configuration
- `POSTGRES_USER`: PostgreSQL username (e.g., `postgres`)
- `POSTGRES_PASSWORD`: PostgreSQL password

### Vault Configuration
- `VAULT_SECRET`: Token for HashiCorp Vault (generate with: `openssl rand -base64 32`)

## Services Included

1. **webui**: Web-based management interface
2. **rps**: Remote Provisioning Server
3. **mps**: Management Presence Server
4. **mpsrouter**: MPS routing service
5. **db**: PostgreSQL database
6. **vault**: HashiCorp Vault for secrets management
7. **kong**: API Gateway
8. **mosquitto**: MQTT broker

## Ports Exposed

- `443`: HTTPS (Kong API Gateway)
- `4433`: MPS communication port
- `5432`: PostgreSQL (for debugging, consider removing in production)
- `8001`: Kong Admin API
- `8200`: Vault API
- `8883`: MQTT over TLS

## Pre-Deployment Setup

### 1. Generate Secrets

```bash
# Generate MPS JWT secret
export MPS_SECRET=$(openssl rand -base64 32)

# Generate Vault token
export VAULT_SECRET=$(openssl rand -base64 32)

# Set other required variables
export MPS_COMMON_NAME="your.domain.com"
export MPS_USER="admin"
export MPS_PASSWORD="YourSecure123!"
export POSTGRES_USER="postgres"
export POSTGRES_PASSWORD="your_db_password"
```

### 2. Validate MPS Password

Ensure `MPS_PASSWORD` meets requirements:
- 8-32 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit (0-9)
- At least one special character

## Post-Deployment Configuration

### 1. Access the Web Interface

Once deployed, access the OpenAMT Web UI at:
- URL: `https://${MPS_COMMON_NAME}` or `https://localhost` (if using localhost)

### 2. Login Credentials

- Username: Value of `${MPS_USER}`
- Password: Value of `${MPS_PASSWORD}`

### 3. Configure AMT Devices

1. Navigate to the Profiles section in the Web UI
2. Create activation profiles for your AMT devices
3. Configure CIRA (Client Initiated Remote Access) settings
4. Use the activation credentials to provision AMT devices

### 4. Verify Services

Check all services are healthy:

```bash
docker-compose ps
```

All services should show "healthy" status after initialization.

## Architecture Overview

```
┌─────────────┐
│   Web UI    │ ───┐
└─────────────┘    │
                   │
┌─────────────┐    │      ┌──────────┐
│ AMT Device  │────┼─────→│   Kong   │ (API Gateway)
└─────────────┘    │      └──────────┘
                   │           │
                   ├───────────┼────→ MPS (Management)
                   │           │
                   └───────────┼────→ RPS (Provisioning)
                               │
                               ├────→ Vault (Secrets)
                               │
                               └────→ PostgreSQL (Database)
```

## Volumes

- `private-volume`: MPS private keys and certificates
- `app-volume`: Application data

## Security Considerations

1. **Change Default Credentials**: Set strong passwords for all services
2. **Use Strong Secrets**: Generate cryptographically secure secrets
3. **Enable TLS**: Ensure MPS_GENERATE_CERTS is "true" for automatic certificate generation
4. **Firewall Rules**: Restrict access to management ports (5432, 8001, 8200)
5. **Vault Security**: In production, use a properly configured Vault instance, not dev mode
6. **Network Isolation**: Consider using a private network for backend services

## Troubleshooting

### Services Won't Start
1. Check environment variables are set: `docker-compose config`
2. Verify password meets requirements
3. Check logs: `docker-compose logs <service_name>`

### Cannot Access Web UI
1. Ensure `MPS_COMMON_NAME` resolves to your server
2. Check Kong is healthy: `docker-compose ps kong`
3. Verify port 443 is not blocked by firewall
4. Check Kong logs: `docker-compose logs kong`

### AMT Device Cannot Connect
1. Verify MPS port 4433 is accessible from AMT devices
2. Check MPS certificates are generated: `docker-compose logs mps`
3. Ensure AMT device configuration points to correct `MPS_COMMON_NAME`
4. Verify CIRA configuration in the device profile

### Database Connection Issues
1. Wait for database to fully initialize (can take 30-60 seconds)
2. Check database health: `docker-compose logs db`
3. Verify connection strings in MPS and RPS services

## Maintenance

### Backup

Backup the following:
- PostgreSQL database volumes
- Vault data
- MPS private volume (certificates and keys)

```bash
docker-compose exec db pg_dump -U ${POSTGRES_USER} mpsdb > mpsdb_backup.sql
docker-compose exec db pg_dump -U ${POSTGRES_USER} rpsdb > rpsdb_backup.sql
```

### Updates

To update to newer versions:
1. Backup current data
2. Update image versions in docker-compose.yml
3. Run `docker-compose pull`
4. Run `docker-compose up -d`

## Documentation

- [Open AMT Cloud Toolkit Documentation](https://open-amt-cloud-toolkit.github.io/docs/)
- [Intel AMT Overview](https://www.intel.com/content/www/us/en/architecture-and-technology/intel-active-management-technology.html)
- [Kong Gateway Documentation](https://docs.konghq.com/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)

## Important Notes

- This configuration uses Vault in **DEV mode** - not suitable for production
- PostgreSQL port 5432 is exposed - consider removing this in production
- Ensure all secrets are stored securely and not committed to version control
- The stack requires significant resources - ensure adequate CPU and RAM
