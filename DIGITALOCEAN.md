# NodeBB DigitalOcean Installation Guide

This guide provides an easy way to install NodeBB on a DigitalOcean droplet with minimal configuration required.

## Quick Start

1. **Create a DigitalOcean Droplet**
   - Choose Ubuntu 20.04 or 22.04 LTS
   - Minimum 2GB RAM recommended (1GB may work for small forums)
   - Add your SSH key for secure access

2. **Point your domain to the droplet**
   - Create an A record pointing your domain to the droplet's IP address
   - Wait for DNS propagation (usually 5-30 minutes)

3. **Run the installation script**
   ```bash
   # SSH into your droplet
   ssh root@your-droplet-ip
   
   # Download and run the installation script
   curl -fsSL https://raw.githubusercontent.com/ShiningVenus/NodeBB/master/install-digitalocean.sh | bash -s your-domain.com
   
   # Or download first, then run
   wget https://raw.githubusercontent.com/ShiningVenus/NodeBB/master/install-digitalocean.sh
   chmod +x install-digitalocean.sh
   sudo ./install-digitalocean.sh your-domain.com
   ```

4. **Complete the setup**
   - Visit your domain in a web browser
   - Follow the NodeBB setup wizard
   - Create your admin account

## What the Script Does

The installation script automatically:

### System Setup
- Updates all system packages
- Installs required dependencies (curl, wget, git, etc.)
- Configures UFW firewall with proper rules

### Docker Installation
- Installs Docker CE from official repository
- Installs Docker Compose
- Configures Docker to start on boot

### Database Setup
- Deploys your chosen database (MongoDB by default)
- Creates secure random passwords
- Configures database for production use

### Web Server Configuration
- Installs and configures Nginx as reverse proxy
- Optimizes Nginx for NodeBB (WebSocket support, static files, etc.)
- Implements security headers and best practices

### SSL/TLS Setup
- Installs Certbot for Let's Encrypt certificates
- Obtains SSL certificate for your domain
- Configures automatic certificate renewal
- Forces HTTPS redirects

### NodeBB Deployment
- Clones the NodeBB repository
- Creates production-ready Docker configuration
- Builds and starts NodeBB containers
- Creates systemd service for automatic startup

### Security Hardening
- Configures firewall (only SSH, HTTP, HTTPS open)
- Disables root SSH login (if SSH keys detected)
- Disables password authentication
- Sets up automatic security updates

## Requirements

### Server Requirements
- Ubuntu 20.04 or 22.04 LTS
- Minimum 2GB RAM (4GB+ recommended for larger forums)
- At least 20GB disk space
- Internet connectivity

### Domain Requirements
- A domain name pointing to your droplet's IP address
- Access to DNS settings to create A records

### Access Requirements
- Root access to the droplet
- SSH access (preferably with SSH keys)

## Database Options

The script supports three database options:

### MongoDB (Default, Recommended)
- Best performance for most use cases
- Native JSON document storage
- Excellent for NodeBB's data structure

### PostgreSQL
- Robust relational database
- Good for data integrity requirements
- Supports complex queries

### Redis
- In-memory database
- Fastest performance
- Requires more RAM
- Good for high-traffic forums

## Directory Structure

After installation, the following structure is created:

```
/opt/nodebb/
└── NodeBB/
    ├── docker-compose.yml
    ├── docker-compose.override.yml
    ├── .docker/
    │   ├── database/
    │   ├── build/
    │   ├── config/
    │   └── public/uploads/
    └── [NodeBB source files]
```

## Management Commands

### Service Management
```bash
# Check NodeBB status
sudo systemctl status nodebb

# Start NodeBB
sudo systemctl start nodebb

# Stop NodeBB
sudo systemctl stop nodebb

# Restart NodeBB
sudo systemctl restart nodebb

# View logs
cd /opt/nodebb/NodeBB
docker-compose logs
docker-compose logs nodebb
docker-compose logs mongo  # or postgres/redis
```

### Updates
```bash
# Update NodeBB
cd /opt/nodebb/NodeBB
git pull
docker-compose up -d --build

# Update system packages
sudo apt update && sudo apt upgrade
```

### SSL Certificate Management
```bash
# Check certificate status
sudo certbot certificates

# Manually renew certificates (automatic renewal is configured)
sudo certbot renew

# Test automatic renewal
sudo certbot renew --dry-run
```

## Customization

### Environment Variables
You can customize NodeBB by editing the `.env` file:

```bash
sudo nano /opt/nodebb/NodeBB/.env
```

### Docker Configuration
Modify the Docker Compose override file for advanced configuration:

```bash
sudo nano /opt/nodebb/NodeBB/docker-compose.override.yml
```

### Nginx Configuration
The Nginx configuration can be found at:

```bash
sudo nano /etc/nginx/sites-available/nodebb
```

After making changes, test and reload:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Backup and Restore

### Database Backup

**MongoDB:**
```bash
# Create backup
docker-compose exec mongo mongodump --db nodebb --out /data/backup

# Copy backup from container
docker cp $(docker-compose ps -q mongo):/data/backup ./backup
```

**PostgreSQL:**
```bash
# Create backup
docker-compose exec postgres pg_dump -U nodebb nodebb > backup.sql
```

### File Backup
```bash
# Backup uploads and config
sudo tar -czf nodebb-files-backup.tar.gz /opt/nodebb/NodeBB/.docker/public/uploads /opt/nodebb/NodeBB/.docker/config
```

## Troubleshooting

### Common Issues

1. **NodeBB not accessible**
   - Check if containers are running: `docker-compose ps`
   - Check logs: `docker-compose logs nodebb`
   - Verify firewall: `sudo ufw status`

2. **SSL certificate issues**
   - Ensure domain points to correct IP
   - Check DNS propagation: `dig your-domain.com`
   - Verify port 80 is accessible for verification

3. **Database connection issues**
   - Check database container: `docker-compose logs mongo`
   - Verify database credentials in override file

4. **Permission issues**
   - Ensure nodebb user owns files: `sudo chown -R nodebb:nodebb /opt/nodebb`

### Getting Help

- Check NodeBB logs: `docker-compose logs nodebb`
- Check system logs: `sudo journalctl -u nodebb`
- Nginx logs: `sudo tail -f /var/log/nginx/error.log`
- NodeBB Community: https://community.nodebb.org

## Security Considerations

### Automatic Security Updates
The script configures automatic security updates. Monitor your server regularly.

### Database Security
- Database passwords are randomly generated
- Databases are not exposed to the internet
- Consider setting up database backups

### Regular Maintenance
- Monitor disk space usage
- Keep Docker images updated
- Review security logs regularly
- Update NodeBB regularly

### Firewall
The script configures UFW with these rules:
- Port 22 (SSH) - Restricted to your IP if possible
- Port 80 (HTTP) - Open for Let's Encrypt verification
- Port 443 (HTTPS) - Open for web traffic

## Performance Optimization

### Server Resources
- Monitor RAM and CPU usage
- Consider upgrading droplet size for high traffic
- Use DigitalOcean monitoring tools

### NodeBB Configuration
- Configure caching in NodeBB admin panel
- Optimize database settings
- Use CDN for static assets if needed

### Database Optimization
- Regular database maintenance
- Monitor query performance
- Consider read replicas for high traffic

## Support

For issues with this installation script:
1. Check the troubleshooting section above
2. Review Docker and system logs
3. Visit the NodeBB community forums
4. Create an issue in the NodeBB repository

For DigitalOcean-specific issues:
- Check DigitalOcean's documentation
- Contact DigitalOcean support
- Use DigitalOcean community forums