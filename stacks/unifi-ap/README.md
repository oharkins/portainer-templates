# UniFi Controller Stack

This stack deploys the Ubiquiti UniFi Network Controller for managing UniFi access points, switches, gateways, and other network devices.

## Overview

The UniFi Controller is a powerful network management software that allows you to:
- Manage UniFi Access Points, Switches, and Security Gateways
- Configure wireless networks and VLANs
- Monitor network performance and client activity
- Create guest portals and hotspots
- Manage firewall rules and routing
- Generate network analytics and reports

Perfect for home automation setups where reliable, manageable networking is essential.

## Prerequisites

- Docker Swarm environment
- UniFi network devices (APs, switches, etc.)
- Network connectivity to UniFi devices
- Sufficient disk space for backups and logs

## Required Environment Variables

- `SYSTEM_IP`: The IP address where the UniFi Controller is accessible (used for device adoption)

## Services Included

### webapp
- UniFi Controller web application
- Manages all UniFi network devices
- Provides web UI and API

### persistence
- MongoDB database
- Stores controller configuration, device settings, statistics

## Ports Exposed

- `8080`: Device inform (required for device adoption)
- `8443`: Controller web UI (HTTPS)
- `8880`: HTTP portal redirect
- `8843`: HTTPS portal redirect
- `3478/udp`: STUN for remote access
- `6789`: Mobile throughput test

## Pre-Deployment Setup

### 1. Set System IP

Determine the IP address where your controller will be accessible:

```bash
export SYSTEM_IP="192.168.1.10"
```

This IP must be reachable by your UniFi devices for adoption.

## Post-Deployment Configuration

### 1. Access the Web UI

Once deployed, access the UniFi Controller at:
- URL: `https://<SYSTEM_IP>:8443`
- Or: `https://<server-ip>:8443`

Accept the self-signed certificate warning (or configure your own certificate).

### 2. Initial Setup Wizard

On first access, complete the setup wizard:

1. **Create Admin Account**
   - Choose a strong username (not "admin")
   - Set a complex password
   - Provide recovery email

2. **Configure Controller**
   - Name your controller
   - Enable auto-backup
   - Configure notifications

3. **Network Setup**
   - Create your wireless network (SSID)
   - Set security (WPA2/WPA3)
   - Configure guest network (optional)

### 3. Adopt UniFi Devices

**Method 1: Automatic Discovery**
1. Ensure devices are on the same network
2. Go to Devices tab
3. Click "Adopt" on discovered devices

**Method 2: SSH Adoption** (if auto-discovery fails)

SSH into your UniFi device and run:
```bash
# For newer firmware
set-inform http://<SYSTEM_IP>:8080/inform

# For older firmware
mca-cli set-inform http://<SYSTEM_IP>:8080/inform
```

**Method 3: DHCP Option 43** (advanced)

Configure DHCP server to provide controller IP via Option 43.

### 4. Configure Wireless Networks

1. Navigate to Settings > Wireless Networks
2. Create SSLIDs for:
   - Main network (WPA2/WPA3)
   - IoT network (isolated VLAN recommended)
   - Guest network (optional)

### 5. VLAN Configuration (Recommended for Home Automation)

Create separate VLANs for security:
- **VLAN 1**: Trusted devices (computers, phones)
- **VLAN 10**: IoT devices (smart home gadgets)
- **VLAN 20**: Guest network
- **VLAN 30**: Management (controller, NAS, etc.)

## Home Automation Best Practices

### Network Segmentation

For a home automation setup, segment your network:

```
┌─────────────────┐
│  Trusted VLAN   │  ← Computers, phones, tablets
│    (VLAN 1)     │
└─────────────────┘

┌─────────────────┐
│   IoT VLAN      │  ← Smart lights, sensors, cameras
│   (VLAN 10)     │  ← Limited internet access
└─────────────────┘

┌─────────────────┐
│  Guest VLAN     │  ← Visitors
│   (VLAN 20)     │  ← Isolated from other networks
└─────────────────┘

┌─────────────────┐
│ Management VLAN │  ← Servers, NAS, Pi-hole
│   (VLAN 30)     │  ← Admin access only
└─────────────────┘
```

### Firewall Rules for IoT Security

Create firewall rules to:
1. Block IoT devices from accessing trusted VLAN
2. Allow IoT to reach Home Assistant/automation hub
3. Block IoT internet access (except specific services)
4. Allow local mDNS/discovery protocols

### DNS Configuration

Point devices to:
- Primary DNS: Pi-hole (ad-blocking)
- Secondary DNS: Unbound (recursive resolver)
- Or use the Unbound stack from this repository

### Static IPs for Critical Devices

Assign static IPs to:
- Home automation hub (Home Assistant, etc.)
- Network attached storage (NAS)
- Security cameras
- Smart home bridges (Zigbee, Z-Wave)

## Volumes

- `webapp-backups`: Automatic controller backups
- `mongo-data`: MongoDB database and configuration

## Backup and Restore

### Automatic Backups

The controller automatically backs up to the `webapp-backups` volume.

### Manual Backup

1. Go to Settings > Maintenance
2. Click "Download Backup"
3. Save the `.unf` file securely

### Copy Backups from Container

```bash
docker run --rm -v unifi-ap_webapp-backups:/backups -v $(pwd):/output alpine cp -r /backups /output
```

### Restore from Backup

1. Access Settings > Maintenance
2. Click "Choose File"
3. Select backup `.unf` file
4. Click "Upload"
5. Controller will restart with restored configuration

## SSL Certificate Configuration

### Using Custom SSL Certificate

1. Access via SSH to the container
2. Import your certificate:
```bash
# Import certificate
keytool -importkeystore \
  -srckeystore cert.p12 -srcstoretype PKCS12 \
  -destkeystore /usr/lib/unifi/data/keystore \
  -deststoretype PKCS12 \
  -destkeypass aircontrolenterprise \
  -alias unifi
```

### Using Let's Encrypt

Consider using a reverse proxy (Traefik, Nginx) with Let's Encrypt for automated SSL.

## Integration with Home Automation

### Presence Detection

UniFi Controller can detect device presence for automation:
- Home Assistant integration available
- Trigger automations based on device connectivity
- Use MAC addresses for person detection

### Guest Network Automation

- Enable guest portal with timed access
- Automate guest network enable/disable
- Create voucher codes for visitors

### Network Monitoring

- Monitor bandwidth usage per device
- Alert on unusual traffic patterns
- Track IoT device behavior

## Troubleshooting

### Devices Not Adopting

1. **Check Network Connectivity**
   ```bash
   ping <device-ip>
   ```

2. **Verify SYSTEM_IP is Correct**
   - Must be reachable from device network
   - Check firewall rules allow port 8080

3. **SSH Adoption**
   ```bash
   ssh ubnt@<device-ip>  # Default password: ubnt
   set-inform http://<SYSTEM_IP>:8080/inform
   ```

4. **Reset Device to Factory Defaults**
   - Hold reset button for 10 seconds
   - Wait for device to reboot
   - Try adoption again

### Cannot Access Web UI

1. Check service is running: `docker service ps <stack>_webapp`
2. Verify port 8443 is not blocked
3. Try HTTP: `http://<ip>:8080` (redirects to HTTPS)
4. Check MongoDB is running: `docker service ps <stack>_persistence`

### MongoDB Connection Issues

1. Wait 2-3 minutes for MongoDB to initialize
2. Check logs: `docker service logs <stack>_persistence`
3. Verify volumes are properly mounted
4. Check disk space

### Slow Performance

1. Increase MongoDB resources
2. Clear old statistics: Settings > Maintenance > Clear Statistics
3. Reduce retention period for logs
4. Offload DPI (Deep Packet Inspection) if enabled

### Device Shows as Disconnected

1. Check device has power and network
2. Verify VLAN configuration
3. Check firewall rules
4. Review device logs in controller

## Performance Optimization

### For Large Deployments (10+ APs)

Update MongoDB configuration:
```yaml
persistence:
  image: mongo
  command: mongod --wiredTigerCacheSizeGB 2
```

### Reduce Log Retention

Settings > Maintenance > Logs:
- Keep logs for 7 days instead of 30
- Reduces database size

### Disable DPI/IDS

If not needed:
- Settings > Security > Disable DPI
- Reduces CPU usage on gateway

## Maintenance

### Regular Tasks

- **Weekly**: Check for firmware updates
- **Monthly**: Review and test backups
- **Monthly**: Review firewall logs
- **Quarterly**: Update controller software
- **Quarterly**: Clean up old statistics

### Update UniFi Devices

1. Navigate to Devices
2. Select device
3. Click "Upgrade"
4. Wait for device to reboot (2-5 minutes)

**Important**: Update APs during low-usage periods.

### Update Controller

```bash
# Backup first!
docker service update --image uip9av6y/unifi-controller:<version> <stack>_webapp
```

## Security Considerations

1. **Change Default Credentials**: Never use default SSH passwords on devices
2. **Use Strong Passwords**: Controller admin password should be complex
3. **Enable 2FA**: Settings > Admins > Enable 2FA
4. **Limit Admin Access**: Create read-only accounts for monitoring
5. **Firewall Controller**: Don't expose 8443 to internet without VPN
6. **Regular Updates**: Keep controller and devices updated
7. **Monitor Logs**: Review unauthorized access attempts
8. **Backup Encryption**: Encrypt backup files if stored off-site

## Advanced Features

### Guest Portal

Settings > Guest Control:
- Enable guest portal
- Customize splash page
- Set access duration
- Generate voucher codes

### Hotspot Manager

For guest authentication:
- Voucher-based access
- Sponsored access
- Payment integration

### DPI (Deep Packet Inspection)

Monitor application usage:
- Identify bandwidth hogs
- Block specific applications
- Create traffic rules

### Auto-Optimize Wi-Fi

Settings > Wireless Networks:
- Enable band steering
- Configure minimum RSSI
- Enable fast roaming (802.11r)

## Integration Examples

### Home Assistant

Add UniFi integration:
```yaml
unifi:
  host: 192.168.1.10
  port: 8443
  username: !secret unifi_username
  password: !secret unifi_password
  verify_ssl: false
  detection_time: 300
```

### Prometheus/Grafana

Export metrics for monitoring:
- Install UniFi Poller
- Visualize network performance
- Alert on issues

## Documentation

- [UniFi Controller Documentation](https://help.ui.com/hc/en-us/categories/200320654-UniFi-Wireless)
- [UniFi Community](https://community.ui.com/)
- [UniFi Network Best Practices](https://help.ui.com/hc/en-us/articles/115012361188)

## Quick Reference

```bash
# Access web UI
https://<SYSTEM_IP>:8443

# SSH to UniFi device
ssh ubnt@<device-ip>

# Adopt device via SSH
set-inform http://<SYSTEM_IP>:8080/inform

# View controller logs
docker service logs <stack>_webapp

# View MongoDB logs
docker service logs <stack>_persistence

# Backup to local directory
docker run --rm -v unifi-ap_webapp-backups:/backups -v $(pwd):/output alpine cp -r /backups /output

# Update controller
docker service update --image uip9av6y/unifi-controller:latest <stack>_webapp
```

## Home Automation Tips

1. **Create dedicated IoT network**: Isolate smart devices for security
2. **Use static IPs**: For critical automation devices
3. **Configure DNS properly**: Point to Pi-hole for ad-blocking
4. **Enable fast roaming**: For mobile devices in automation scenarios
5. **Monitor presence**: Use for home/away automation triggers
6. **Create firewall rules**: Restrict IoT device internet access
7. **Regular firmware updates**: Keep devices secure
8. **Use VLANs extensively**: Segment network by device type and trust level
