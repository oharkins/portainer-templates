# n8n Stack Configuration

This stack deploys n8n, a workflow automation tool with Traefik as a reverse proxy.

## Prerequisites

- Docker Swarm or Docker Compose environment
- Domain name configured to point to your server
- Port 8080 and 8443 available

## Required Environment Variables

Before deploying this stack, you need to configure the following environment variables:

### SSL/Domain Configuration
- `SSL_EMAIL`: Email address for Let's Encrypt SSL certificate registration
- `DOMAIN_NAME`: Your root domain (e.g., `example.com`)
- `SUBDOMAIN`: Subdomain for n8n (e.g., `n8n` will create `n8n.example.com`)

### n8n Authentication
- `N8N_BASIC_AUTH_USER`: Username for basic authentication
- `N8N_BASIC_AUTH_PASSWORD`: Password for basic authentication

### n8n Encryption
- `N8N_ENCRYPTION_KEY`: A long random string for encrypting credentials (generate with: `openssl rand -hex 32`)

### Data Storage
- `DATA_FOLDER`: Path on host where n8n data and Let's Encrypt certificates will be stored

### Optional Configuration
- `GENERIC_TIMEZONE`: Timezone (default: `UTC`, e.g., `America/New_York`)

## Post-Deployment Configuration

### 1. Create Required Directories

```bash
mkdir -p ${DATA_FOLDER}/.n8n
mkdir -p ${DATA_FOLDER}/letsencrypt
chmod 600 ${DATA_FOLDER}/letsencrypt
```

### 2. Access n8n

Once deployed, access n8n at:
- HTTPS: `https://${SUBDOMAIN}.${DOMAIN_NAME}`
- The application will automatically redirect HTTP to HTTPS

### 3. First Login

Use the credentials specified in `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD`.

## Services Included

- **Traefik**: Reverse proxy with automatic SSL certificate generation
- **n8n**: Workflow automation platform

## Ports Exposed

- `8080`: HTTP (redirects to HTTPS)
- `8443`: HTTPS
- `127.0.0.1:5678`: n8n direct access (localhost only)

## Volumes

- `${DATA_FOLDER}/.n8n`: n8n data and workflows
- `${DATA_FOLDER}/letsencrypt`: SSL certificates

## Security Notes

- The stack uses Let's Encrypt for automatic SSL certificate generation
- Basic authentication is enabled by default
- Change the default credentials before deploying to production
- Ensure the encryption key is kept secure and backed up

## Troubleshooting

### Certificate Issues
If Let's Encrypt certificates fail to generate:
1. Verify your domain DNS points to this server
2. Ensure ports 80 and 443 are not blocked by firewall
3. Check Traefik logs: `docker logs <traefik_container_id>`

### Connection Issues
If you cannot access n8n:
1. Verify Traefik is running: `docker ps | grep traefik`
2. Check n8n logs: `docker logs <n8n_container_id>`
3. Ensure environment variables are set correctly

## Documentation

- [n8n Documentation](https://docs.n8n.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
