# Watchtower Stack

Watchtower automatically updates running Docker containers when new images are available. Perfect for keeping your home automation stack up-to-date with minimal manual intervention.

## Overview

Watchtower monitors all running Docker containers and checks for updated images. When an update is found, it:
1. Pulls the new image
2. Stops the existing container
3. Starts a new container with the updated image
4. Removes the old image (when --cleanup is enabled)

## Important Warning

⚠️ **Use with caution in production!**

Watchtower will automatically update containers, which can:
- Break your setup if updates introduce breaking changes
- Cause unexpected downtime
- Override specific version pins

**Best Practice**: Test updates in a dev environment first, or use Watchtower selectively with labels.

## Prerequisites

- Docker Swarm environment
- Running containers to monitor
- Understanding of your application update requirements

## Required Environment Variables

- `CRON_SCHEDULE`: Cron expression for when to check for updates (e.g., `0 0 4 * * *` for 4 AM daily)

## Service Configuration

### monitor
- Deployed globally (one instance per swarm node)
- Monitors all containers on each node
- Runs on a schedule defined by `CRON_SCHEDULE`
- Has access to Docker socket

## Deployment Modes

### Mode 1: Update All Containers (Current Configuration)

Updates every container on every schedule run.

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
```

### Mode 2: Monitor Specific Containers Only (Recommended)

Use labels to control which containers get updated:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --label-enable
```

Then label containers you want updated:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

### Mode 3: Run Once (Manual Trigger)

Remove the schedule for manual-only updates:
```yaml
command:
  - --cleanup
  - --run-once
```

## Pre-Deployment Setup

### 1. Choose Update Schedule

Set your cron schedule:

```bash
# Daily at 4 AM
export CRON_SCHEDULE="0 0 4 * * *"

# Every Sunday at 3 AM
export CRON_SCHEDULE="0 0 3 * * SUN"

# Every 6 hours
export CRON_SCHEDULE="0 0 */6 * * *"

# Every day at 2 AM and 2 PM
export CRON_SCHEDULE="0 0 2,14 * * *"
```

### 2. Decide Update Strategy

Choose which containers to update:
- **All containers**: Use default configuration
- **Specific containers**: Add `--label-enable` flag
- **All except some**: Use `--label-disable` flag

## Cron Schedule Format

```
┌───────────── second (0-59)
│ ┌───────────── minute (0-59)
│ │ ┌───────────── hour (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12)
│ │ │ │ │ ┌───────────── day of week (0-6) (Sunday to Saturday)
│ │ │ │ │ │
│ │ │ │ │ │
* * * * * *
```

### Examples

```bash
# Every day at 4 AM
"0 0 4 * * *"

# Every Monday at 3 AM
"0 0 3 * * MON"

# Every 12 hours
"0 0 */12 * * *"

# First day of every month at midnight
"0 0 0 1 * *"

# Weekdays at 6 AM
"0 0 6 * * MON-FRI"
```

## Post-Deployment Configuration

### 1. Verify Watchtower is Running

```bash
docker service ps <stack>_monitor
```

### 2. Check Logs

```bash
docker service logs <stack>_monitor

# Follow logs in real-time
docker service logs -f <stack>_monitor
```

### 3. Monitor Updates

Watchtower logs show:
- Containers checked
- Updates found
- Updates applied
- Errors encountered

## Selective Updates with Labels

### Enable Label-Based Updates

Update the stack to use labels:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --label-enable
```

### Label Containers for Auto-Update

Add to containers you want updated:

```yaml
services:
  homeassistant:
    image: homeassistant/home-assistant:latest
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

### Exclude Containers from Updates

```yaml
services:
  database:
    image: postgres:14
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

## Advanced Configuration

### Enable Notifications

Add Slack, Discord, Email, or other notifications:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --notifications slack
  - --notification-slack-hook-url "${SLACK_WEBHOOK_URL}"
  - --notification-slack-identifier watchtower
```

### Stop Containers Gracefully

Add timeout for graceful shutdown:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --stop-timeout 30s
```

### Update Specific Containers Only

Monitor only certain containers by name:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  homeassistant mqtt grafana
```

### Include Stopped Containers

Also update stopped containers:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --include-stopped
```

### Enable Debug Logging

For troubleshooting:

```yaml
command:
  - --cleanup
  - --schedule "${CRON_SCHEDULE}"
  - --debug
```

## Home Automation Recommendations

### Safe Update Strategy for Home Automation

```yaml
# Only update non-critical services
command:
  - --cleanup
  - --schedule "0 0 3 * * *"  # 3 AM daily
  - --label-enable

# Label safe-to-update containers
services:
  grafana:
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  # DON'T auto-update critical services
  homeassistant:
    # No label = won't be updated

  database:
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

### Containers to Auto-Update Safely

- **Monitoring**: Grafana, Prometheus exporters
- **Utilities**: Watchtower itself
- **Non-critical**: Test environments

### Containers to Update Manually

- **Home Assistant**: Breaking changes common
- **Databases**: PostgreSQL, MySQL, InfluxDB
- **MQTT Brokers**: Mosquitto, RabbitMQ
- **Reverse Proxies**: Traefik, Nginx
- **Automation Hubs**: Node-RED, n8n

## Notification Configuration

### Slack Notifications

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=slack
  - WATCHTOWER_NOTIFICATION_SLACK_HOOK_URL=${SLACK_WEBHOOK}
  - WATCHTOWER_NOTIFICATION_SLACK_IDENTIFIER=watchtower-home
```

### Discord Notifications

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=discord
  - WATCHTOWER_NOTIFICATION_DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK}
```

### Email Notifications

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=email
  - WATCHTOWER_NOTIFICATION_EMAIL_FROM=watchtower@example.com
  - WATCHTOWER_NOTIFICATION_EMAIL_TO=admin@example.com
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER=smtp.gmail.com
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_PORT=587
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_USER=${SMTP_USER}
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_PASSWORD=${SMTP_PASSWORD}
```

### Gotify Notifications

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=gotify
  - WATCHTOWER_NOTIFICATION_GOTIFY_URL=${GOTIFY_URL}
  - WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=${GOTIFY_TOKEN}
```

## Monitoring Watchtower

### View Recent Updates

```bash
# Last 50 log lines
docker service logs --tail 50 <stack>_monitor

# Follow updates in real-time
docker service logs -f <stack>_monitor | grep -i "updating"
```

### Check for Errors

```bash
docker service logs <stack>_monitor | grep -i "error"
```

### Verify Containers Were Updated

```bash
# Check container creation time
docker ps --format "table {{.Names}}\t{{.CreatedAt}}\t{{.Status}}"
```

## Troubleshooting

### Watchtower Not Updating Containers

1. **Check Schedule**: Verify cron expression is correct
2. **Check Labels**: If using `--label-enable`, ensure containers are labeled
3. **Check Logs**: Look for errors in Watchtower logs
4. **Check Docker Socket**: Ensure `/var/run/docker.sock` is mounted
5. **Check Image Tags**: Only `latest` or version tags are updated

### Container Fails After Update

1. **Check Container Logs**: `docker logs <container>`
2. **Roll Back**: Manually deploy previous version
3. **Pin Version**: Use specific version tag instead of `latest`
4. **Exclude from Auto-Update**: Add label to prevent future updates

### No Notifications Received

1. Verify webhook URL is correct
2. Check notification service is reachable
3. Test webhook manually
4. Check Watchtower logs for notification errors

### High Resource Usage

1. Reduce check frequency (longer schedule)
2. Monitor specific containers only
3. Reduce concurrent updates

## Best Practices

### 1. Pin Critical Services

Use specific versions for critical services:
```yaml
homeassistant:
  image: homeassistant/home-assistant:2024.1.0  # Not :latest
```

### 2. Test Updates in Development

- Run a dev environment with `latest` tags
- Let Watchtower update dev first
- Test for 24-48 hours
- Manually update production

### 3. Schedule During Low Usage

```bash
# Update at 3 AM when home automation is less active
export CRON_SCHEDULE="0 0 3 * * *"
```

### 4. Enable Notifications

Always know when updates happen:
- Slack/Discord for instant alerts
- Email for summaries
- Gotify for push notifications

### 5. Use Health Checks

Ensure containers have health checks:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8123"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### 6. Backup Before Updates

Combine with automated backups:
- Backup at 2 AM
- Update at 3 AM
- Easy rollback if needed

## Security Considerations

1. **Docker Socket Access**: Watchtower has full Docker control
2. **Image Verification**: Ensure you trust image sources
3. **Network Security**: Consider using private registries
4. **Least Privilege**: Only update necessary containers
5. **Update Review**: Monitor logs for unexpected updates

## Alternative Strategies

### Manual Updates with Watchtower

Run Watchtower manually instead of scheduled:

```bash
# One-time update check
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --cleanup --run-once

# Update specific container
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --cleanup --run-once grafana
```

### Watchtower + Approval Workflow

1. Watchtower checks for updates (notifications only)
2. Review changelog
3. Manually approve and update
4. Use `--run-once` mode

### Staged Rollout

Update in phases:
- Day 1: Non-critical services
- Day 3: Monitoring and logging
- Week 2: Critical automation services (manually)

## Integration with Home Automation

### Home Assistant Automation Example

Get notified when containers update:

```yaml
automation:
  - alias: "Container Updated Notification"
    trigger:
      - platform: webhook
        webhook_id: watchtower_update
    action:
      - service: notify.mobile_app
        data:
          title: "Container Updated"
          message: "Watchtower updated {{ trigger.json.container }}"
```

### Node-RED Flow

Create Node-RED flow to:
1. Receive Watchtower webhooks
2. Log updates to database
3. Send notifications
4. Trigger health checks

## Maintenance

### Regular Tasks

- **Weekly**: Review Watchtower logs
- **Monthly**: Verify all containers still working post-updates
- **Quarterly**: Review update strategy and adjust as needed

### Cleanup Old Images

Watchtower with `--cleanup` removes old images automatically. Verify:

```bash
# Check for dangling images
docker images -f "dangling=true"

# Manual cleanup if needed
docker image prune -a
```

## Documentation

- [Watchtower Documentation](https://containrrr.dev/watchtower/)
- [Notification Options](https://containrrr.dev/watchtower/notifications/)
- [Arguments Reference](https://containrrr.dev/watchtower/arguments/)

## Quick Reference

```bash
# View Watchtower logs
docker service logs <stack>_monitor

# Force update check now
docker service update --force <stack>_monitor

# Test cron schedule
# Use https://crontab.guru/ for validation

# Common schedules
Daily at 3 AM:     "0 0 3 * * *"
Weekly Sunday:     "0 0 3 * * SUN"
Every 6 hours:     "0 0 */6 * * *"
First of month:    "0 0 0 1 * *"

# Label containers for selective updates
labels:
  - "com.centurylinklabs.watchtower.enable=true"

# Exclude from updates
labels:
  - "com.centurylinklabs.watchtower.enable=false"

# Check container update times
docker ps --format "table {{.Names}}\t{{.CreatedAt}}"
```

## Recommended Configuration for Home Automation

```yaml
version: '3.2'

services:
  monitor:
    image: containrrr/watchtower
    command:
      - --cleanup
      - --schedule "0 0 3 * * *"  # 3 AM daily
      - --label-enable              # Only update labeled containers
      - --notifications slack
      - --notification-slack-hook-url "${SLACK_WEBHOOK}"
    environment:
      - TZ=America/New_York
    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
    deploy:
      mode: global
      restart_policy:
        condition: any
```

Then label only safe containers for auto-update!
