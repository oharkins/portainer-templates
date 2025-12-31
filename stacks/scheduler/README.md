# Container Scheduler (Crontab) Stack

This stack deploys Rancher's Container Crontab, which provides cron-like scheduled execution for Docker containers. Perfect for running periodic tasks, backups, maintenance jobs, and automation workflows.

## Overview

Container Crontab watches for containers with special labels that define cron schedules. When the scheduled time arrives, it executes the specified container, similar to how traditional cron works.

## Use Cases for Home Automation

- **Automated Backups**: Schedule nightly backups of Home Assistant, databases
- **Data Collection**: Periodic scraping of weather, energy data
- **Cleanup Tasks**: Remove old logs, temporary files
- **Health Checks**: Scheduled monitoring and alerting
- **Automation Triggers**: Time-based home automation events
- **Database Maintenance**: Vacuum, optimize databases
- **Certificate Renewal**: Check and renew SSL certificates
- **Report Generation**: Daily/weekly analytics reports

## Prerequisites

- Docker Swarm environment
- Docker socket access
- Containers labeled with cron schedules

## Service Configuration

### crontab
- Deployed globally (monitors all nodes)
- Has access to Docker socket
- Watches for labeled containers
- Executes containers on schedule

## How It Works

1. **Label Containers**: Add schedule labels to containers
2. **Crontab Monitors**: Container Crontab watches for these labels
3. **Execute on Schedule**: At scheduled time, container runs
4. **Container Stops**: After execution, container stops (if configured)

## Schedule Label Format

Add this label to containers you want to schedule:

```yaml
labels:
  io.rancher.container.crontab.schedule: "0 2 * * *"
```

Or use the simpler format for common schedules:

```yaml
labels:
  io.rancher.container.crontab.schedule: "@daily"
```

## Cron Schedule Syntax

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
│ │ │ │ │
* * * * *
```

### Common Cron Expressions

```bash
# Every minute
* * * * *

# Every hour
0 * * * *

# Every day at 2 AM
0 2 * * *

# Every Sunday at 3 AM
0 3 * * 0

# Every weekday at 6 AM
0 6 * * 1-5

# First day of every month
0 0 1 * *

# Every 6 hours
0 */6 * * *

# Twice daily (6 AM and 6 PM)
0 6,18 * * *
```

### Named Schedules

```yaml
@yearly   # or @annually  → "0 0 1 1 *"
@monthly                  → "0 0 1 * *"
@weekly                   → "0 0 * * 0"
@daily    # or @midnight  → "0 0 * * *"
@hourly                   → "0 * * * *"
```

## Example Scheduled Containers

### Example 1: Nightly Database Backup

```yaml
version: '3.2'

services:
  postgres-backup:
    image: postgres:15
    command: |
      sh -c 'pg_dump -h postgres -U ${POSTGRES_USER} ${POSTGRES_DB} > /backup/backup_$(date +%Y%m%d_%H%M%S).sql'
    environment:
      - PGPASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - backup-data:/backup
    labels:
      - "io.rancher.container.crontab.schedule=0 2 * * *"
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none

volumes:
  backup-data:
```

### Example 2: Home Assistant Backup

```yaml
services:
  ha-backup:
    image: alpine
    command: |
      sh -c 'tar czf /backup/homeassistant_$(date +%Y%m%d).tar.gz -C /config .'
    volumes:
      - ha-config:/config:ro
      - backup-data:/backup
    labels:
      - "io.rancher.container.crontab.schedule=@daily"
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none
```

### Example 3: Log Cleanup

```yaml
services:
  log-cleanup:
    image: alpine
    command: find /logs -name "*.log" -mtime +7 -delete
    volumes:
      - log-data:/logs
    labels:
      - "io.rancher.container.crontab.schedule=@weekly"
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none
```

### Example 4: Certificate Renewal Check

```yaml
services:
  cert-renew:
    image: certbot/certbot
    command: renew --dry-run
    volumes:
      - letsencrypt:/etc/letsencrypt
    labels:
      - "io.rancher.container.crontab.schedule=0 0 */7 * *"  # Weekly
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none
```

### Example 5: Database Maintenance

```yaml
services:
  db-vacuum:
    image: postgres:15
    command: psql -h postgres -U ${POSTGRES_USER} -c "VACUUM ANALYZE;"
    environment:
      - PGPASSWORD=${POSTGRES_PASSWORD}
    labels:
      - "io.rancher.container.crontab.schedule=0 3 * * 0"  # Sunday 3 AM
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none
```

## Post-Deployment Configuration

### 1. Verify Scheduler is Running

```bash
docker service ps <stack>_crontab
```

### 2. Check Logs

```bash
docker service logs <stack>_crontab

# Follow in real-time
docker service logs -f <stack>_crontab
```

### 3. Verify Scheduled Containers

The crontab service logs will show:
- Discovered scheduled containers
- Execution times
- Container start/stop events

## Important Labels

### Schedule Label (Required)

```yaml
labels:
  io.rancher.container.crontab.schedule: "0 2 * * *"
```

### Start Once Label (Recommended)

Ensures container runs once per schedule (doesn't restart):

```yaml
labels:
  io.rancher.container.start_once: "true"
```

### Restart Policy (Important)

Use `restart_policy: condition: none` for scheduled containers:

```yaml
deploy:
  restart_policy:
    condition: none
```

This prevents containers from auto-restarting after completing.

## Advanced Configurations

### Run Container with Timeout

Prevent stuck jobs:

```yaml
services:
  backup-job:
    image: alpine
    command: timeout 300 sh -c 'your-backup-script.sh'
    labels:
      - "io.rancher.container.crontab.schedule=@daily"
```

### Retry on Failure

```yaml
services:
  backup-job:
    image: alpine
    command: |
      sh -c '
        for i in 1 2 3; do
          if backup.sh; then exit 0; fi
          sleep 60
        done
        exit 1
      '
    labels:
      - "io.rancher.container.crontab.schedule=@daily"
```

### Notify on Completion

```yaml
services:
  backup-with-notify:
    image: alpine
    command: |
      sh -c '
        backup.sh && curl -X POST ${WEBHOOK_URL} -d "Backup completed"
      '
    environment:
      - WEBHOOK_URL=${WEBHOOK_URL}
    labels:
      - "io.rancher.container.crontab.schedule=@daily"
```

## Home Automation Examples

### Scrape Weather Data

```yaml
services:
  weather-scraper:
    image: python:3.9-alpine
    command: python /app/scrape_weather.py
    volumes:
      - ./scripts:/app
      - weather-data:/data
    labels:
      - "io.rancher.container.crontab.schedule=0 * * * *"  # Hourly
      - "io.rancher.container.start_once=true"
```

### Energy Monitor Data Collection

```yaml
services:
  energy-collect:
    image: alpine
    command: |
      sh -c 'curl http://energy-monitor/api/data > /data/energy_$(date +%Y%m%d_%H%M).json'
    volumes:
      - energy-data:/data
    labels:
      - "io.rancher.container.crontab.schedule=*/15 * * * *"  # Every 15 min
      - "io.rancher.container.start_once=true"
```

### Cleanup Old Camera Recordings

```yaml
services:
  camera-cleanup:
    image: alpine
    command: find /recordings -name "*.mp4" -mtime +30 -delete
    volumes:
      - camera-recordings:/recordings
    labels:
      - "io.rancher.container.crontab.schedule=@daily"
      - "io.rancher.container.start_once=true"
```

### Smart Home State Backup

```yaml
services:
  state-backup:
    image: alpine
    command: |
      sh -c 'mosquitto_sub -h mqtt -t "#" -C 1000 > /backup/mqtt_state_$(date +%Y%m%d).txt'
    volumes:
      - mqtt-backup:/backup
    labels:
      - "io.rancher.container.crontab.schedule=0 0 * * *"  # Daily
      - "io.rancher.container.start_once=true"
```

## Monitoring Scheduled Jobs

### View Job Execution History

```bash
# Check scheduler logs for job execution
docker service logs <stack>_crontab | grep -i "executing"

# Check specific job logs
docker logs <job-container-name>
```

### Alert on Failed Jobs

Create a monitoring container that checks for failures:

```yaml
services:
  job-monitor:
    image: alpine
    command: |
      sh -c '
        if [ $(docker ps -a -f "label=io.rancher.container.crontab.schedule" -f "status=exited" -f "exited=1" -q | wc -l) -gt 0 ]; then
          curl -X POST ${ALERT_WEBHOOK} -d "Scheduled job failed"
        fi
      '
    labels:
      - "io.rancher.container.crontab.schedule=*/5 * * * *"  # Check every 5 min
```

## Troubleshooting

### Job Not Running

1. **Check Schedule Syntax**
   - Verify cron expression is valid
   - Use https://crontab.guru/ to test

2. **Check Label Format**
   ```bash
   docker inspect <container> | grep -A5 Labels
   ```

3. **Check Scheduler Logs**
   ```bash
   docker service logs <stack>_crontab
   ```

4. **Verify Container Can Start**
   ```bash
   # Test manually
   docker service update --force <service-name>
   ```

### Job Runs But Fails

1. **Check Job Logs**
   ```bash
   docker ps -a | grep <job-name>
   docker logs <container-id>
   ```

2. **Test Command Manually**
   ```bash
   docker run --rm <image> <command>
   ```

3. **Check Permissions**
   - Ensure volumes are writable
   - Verify network access

### Multiple Job Instances Running

Add `start_once` label:
```yaml
labels:
  - "io.rancher.container.start_once=true"
```

And set restart policy:
```yaml
deploy:
  restart_policy:
    condition: none
```

### Jobs Not Stopping After Completion

Ensure command exits properly:
```yaml
command: sh -c 'your-script.sh; exit $?'
```

## Best Practices

### 1. Always Set Restart Policy

```yaml
deploy:
  restart_policy:
    condition: none
```

### 2. Use Descriptive Names

```yaml
services:
  homeassistant-daily-backup:  # Clear purpose
```

### 3. Add Timeouts

```yaml
command: timeout 600 backup-script.sh  # 10 minute timeout
```

### 4. Log Everything

```yaml
command: |
  sh -c '
    echo "Starting backup at $(date)" >> /logs/backup.log
    backup.sh 2>&1 | tee -a /logs/backup.log
    echo "Completed at $(date)" >> /logs/backup.log
  '
```

### 5. Test Schedules

```yaml
# Test with frequent schedule first
labels:
  - "io.rancher.container.crontab.schedule=*/5 * * * *"  # Every 5 min

# Then change to production schedule
labels:
  - "io.rancher.container.crontab.schedule=0 2 * * *"  # Daily at 2 AM
```

### 6. Handle Failures Gracefully

```yaml
command: |
  sh -c '
    if backup.sh; then
      echo "Success" > /status/last_run
    else
      echo "Failed" > /status/last_run
      curl -X POST ${ALERT_URL} -d "Backup failed"
    fi
  '
```

### 7. Cleanup Old Backups

```yaml
command: |
  sh -c '
    backup.sh
    find /backup -name "*.tar.gz" -mtime +7 -delete
  '
```

## Integration with Other Services

### Home Assistant Automation

Trigger automation after scheduled job completes:

```yaml
# Job posts to webhook when done
command: |
  sh -c '
    backup.sh
    curl -X POST http://homeassistant:8123/api/webhook/backup_complete
  '
```

Home Assistant automation:
```yaml
automation:
  - alias: "Backup Complete Notification"
    trigger:
      - platform: webhook
        webhook_id: backup_complete
    action:
      - service: notify.mobile_app
        data:
          message: "Nightly backup completed successfully"
```

### Healthchecks.io Integration

Monitor job completion:

```yaml
command: |
  sh -c '
    curl https://hc-ping.com/${JOB_UUID}/start
    if backup.sh; then
      curl https://hc-ping.com/${JOB_UUID}
    else
      curl https://hc-ping.com/${JOB_UUID}/fail
    fi
  '
```

## Security Considerations

1. **Docker Socket Access**: Scheduler has full Docker access
2. **Secrets Management**: Use Docker secrets for sensitive data
3. **Least Privilege**: Run jobs with minimal permissions
4. **Network Isolation**: Use dedicated networks for jobs
5. **Image Trust**: Only use trusted images for scheduled jobs

## Maintenance

### Regular Tasks

- **Weekly**: Review scheduled job logs
- **Monthly**: Test job recovery procedures
- **Quarterly**: Review and optimize schedules

### Cleanup Failed Containers

```bash
# Remove old failed job containers
docker container prune -f --filter "label=io.rancher.container.crontab.schedule"
```

## Documentation

- [Rancher Container Crontab](https://github.com/rancher/container-crontab)
- [Cron Expression Tester](https://crontab.guru/)

## Quick Reference

```bash
# View scheduler logs
docker service logs <stack>_crontab

# List all scheduled containers
docker ps -a -f "label=io.rancher.container.crontab.schedule"

# Check specific job logs
docker logs <job-container-id>

# Test cron expression
# Visit: https://crontab.guru/

# Common schedules
Every minute:       * * * * *
Hourly:             0 * * * *
Daily at 2 AM:      0 2 * * *
Weekly Sunday:      0 3 * * 0
Monthly:            0 0 1 * *
Every 6 hours:      0 */6 * * *

# Required labels for scheduled jobs
labels:
  - "io.rancher.container.crontab.schedule=0 2 * * *"
  - "io.rancher.container.start_once=true"

# Required restart policy
deploy:
  restart_policy:
    condition: none
```

## Example: Complete Backup Solution

```yaml
version: '3.2'

services:
  # Database backup
  db-backup:
    image: postgres:15
    command: |
      sh -c '
        echo "Starting backup at $(date)"
        pg_dump -h postgres -U ${POSTGRES_USER} ${POSTGRES_DB} | gzip > /backup/db_$(date +%Y%m%d_%H%M%S).sql.gz
        find /backup -name "*.sql.gz" -mtime +7 -delete
        echo "Backup complete at $(date)"
      '
    environment:
      - PGPASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - backup-data:/backup
    labels:
      - "io.rancher.container.crontab.schedule=0 2 * * *"
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none

  # Home Assistant config backup
  ha-backup:
    image: alpine
    command: |
      sh -c '
        tar czf /backup/homeassistant_$(date +%Y%m%d).tar.gz -C /config .
        find /backup -name "homeassistant_*.tar.gz" -mtime +30 -delete
        curl -X POST ${WEBHOOK_URL} -d "HA backup complete"
      '
    volumes:
      - ha-config:/config:ro
      - backup-data:/backup
    environment:
      - WEBHOOK_URL=${WEBHOOK_URL}
    labels:
      - "io.rancher.container.crontab.schedule=0 3 * * *"
      - "io.rancher.container.start_once=true"
    deploy:
      restart_policy:
        condition: none

volumes:
  backup-data:
  ha-config:
    external: true
```
