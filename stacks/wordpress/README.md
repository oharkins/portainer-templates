# WordPress Stack

This stack deploys WordPress with a MySQL database.

## Prerequisites

- Docker Swarm or Docker Compose environment
- Available port 80 (or configure a different port)

## Required Environment Variables

Before deploying this stack, configure:

- `MYSQL_DATABASE_PASSWORD`: Root password for MySQL database

## Optional Configuration

You can modify the following in the docker-stack.yml if needed:
- MySQL database name (default: `wordpress`)
- MySQL username (default: `wordpress`)
- MySQL password (default: `wordpress`)
- WordPress database password (default: `wordpress`)

**Security Note**: The default MySQL user password is `wordpress`. For production deployments, you should change this in the stack file.

## Post-Deployment Configuration

### 1. Access WordPress

Once deployed, access WordPress at:
- URL: `http://<your-server-ip>` or through your configured domain

### 2. WordPress Installation

On first access, you'll see the WordPress installation wizard:

1. **Select Language**: Choose your preferred language
2. **Site Information**:
   - Site Title
   - Admin Username (don't use 'admin')
   - Admin Password (strong password required)
   - Admin Email
3. **Click "Install WordPress"**
4. **Login** with your admin credentials

### 3. Recommended Post-Installation Steps

1. **Update Permalink Structure**:
   - Go to Settings > Permalinks
   - Choose a SEO-friendly structure (e.g., "Post name")

2. **Install Security Plugin**:
   - Wordfence Security or similar
   - Configure firewall and malware scanning

3. **Install Backup Plugin**:
   - UpdraftPlus or similar
   - Configure automatic backups

4. **Configure Updates**:
   - Keep WordPress, themes, and plugins updated
   - Consider automatic updates for minor releases

5. **SSL/HTTPS Setup** (if using a reverse proxy):
   - Configure your reverse proxy for SSL
   - Install Really Simple SSL plugin
   - Update site URL in Settings > General

## Services Included

- **WordPress**: Latest WordPress version
- **MySQL 5.7**: Database server

## Volumes

- `db_data`: MySQL database files (persistent storage)

## Database Configuration

- **Database Host**: `db:3306`
- **Database Name**: `wordpress`
- **Database User**: `wordpress`
- **Database Password**: `wordpress` (change in production!)
- **Root Password**: `${MYSQL_DATABASE_PASSWORD}`

## Security Considerations

1. **Change Default Passwords**: Update the MySQL user password before production deployment
2. **Use Strong Passwords**: Set a complex password for `MYSQL_DATABASE_PASSWORD`
3. **Don't Use 'admin' Username**: Create a unique admin username during WordPress setup
4. **Enable HTTPS**: Use a reverse proxy (like Nginx or Traefik) with SSL certificates
5. **Limit Login Attempts**: Install a security plugin to prevent brute force attacks
6. **Regular Backups**: Backup both WordPress files and MySQL database
7. **Keep Updated**: Regularly update WordPress core, themes, and plugins
8. **File Permissions**: Ensure proper file permissions (WordPress will warn if incorrect)

## Enhancing for Production

To make this production-ready, consider:

### 1. Add Redis for Caching

Add a Redis service and install the Redis Object Cache plugin.

### 2. Use a Reverse Proxy

Add Nginx or Traefik with:
- SSL/TLS certificates (Let's Encrypt)
- HTTP to HTTPS redirect
- Security headers

### 3. Separate Database Password

Update the stack to use a different password for the WordPress database user:

```yaml
environment:
  MYSQL_DATABASE: wordpress
  MYSQL_USER: wordpress
  MYSQL_PASSWORD: ${WORDPRESS_DB_PASSWORD}
```

### 4. Add Volume for WordPress Files

Add persistence for WordPress uploads and plugins:

```yaml
wordpress:
  volumes:
    - wordpress_data:/var/www/html
```

### 5. Configure PHP Settings

Create a custom php.ini for upload limits and memory:

```ini
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
```

## Backup and Restore

### Backup Database

```bash
docker exec <mysql_container> mysqldump -u root -p${MYSQL_DATABASE_PASSWORD} wordpress > wordpress_backup.sql
```

### Restore Database

```bash
docker exec -i <mysql_container> mysql -u root -p${MYSQL_DATABASE_PASSWORD} wordpress < wordpress_backup.sql
```

### Backup WordPress Files

```bash
docker exec <wordpress_container> tar czf /tmp/wordpress-files.tar.gz /var/www/html
docker cp <wordpress_container>:/tmp/wordpress-files.tar.gz ./wordpress-files.tar.gz
```

## Troubleshooting

### Cannot Connect to Database

1. Wait 30-60 seconds for MySQL to initialize on first run
2. Check MySQL logs: `docker logs <mysql_container>`
3. Verify environment variables are set correctly
4. Ensure both containers are on the same network

### Error Establishing Database Connection

1. Check database service is running: `docker ps`
2. Verify database credentials in WordPress configuration
3. Check MySQL logs for errors
4. Restart the stack: `docker-compose restart`

### Upload Size Limit

If you need to upload larger files:
1. Create a custom `php.ini` or `.htaccess` file
2. Mount it as a volume in the WordPress container
3. Restart the container

### Slow Performance

1. Install a caching plugin (WP Super Cache or W3 Total Cache)
2. Optimize images before uploading
3. Use a CDN for static assets
4. Consider adding Redis or Memcached
5. Increase PHP memory limit

## Maintenance

### Regular Tasks

1. **Weekly**: Check for updates to WordPress, themes, and plugins
2. **Weekly**: Review security plugin logs
3. **Daily**: Automated backups (configure with plugin)
4. **Monthly**: Test backup restoration
5. **Monthly**: Review and clean spam comments

### Update WordPress

WordPress can update itself through the admin panel. For docker-based updates:

```bash
docker-compose pull wordpress
docker-compose up -d wordpress
```

## Documentation

- [WordPress Documentation](https://wordpress.org/support/)
- [WordPress Installation Guide](https://wordpress.org/support/article/how-to-install-wordpress/)
- [WordPress Security](https://wordpress.org/support/article/hardening-wordpress/)
- [MySQL Documentation](https://dev.mysql.com/doc/)

## Default Credentials

**Set during WordPress installation**
- WordPress Admin: (you choose during setup)

**Database** (change before production!):
- MySQL Root: `${MYSQL_DATABASE_PASSWORD}`
- MySQL User: `wordpress`
- MySQL Password: `wordpress`
- MySQL Database: `wordpress`
