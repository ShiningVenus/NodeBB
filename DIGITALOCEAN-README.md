# DigitalOcean Deployment Files

This directory contains files for deploying NodeBB on DigitalOcean infrastructure.

## Files Overview

### Installation Scripts
- **`install-digitalocean.sh`** - Complete automated installation script for DigitalOcean droplets
- **`install-quick.sh`** - One-liner quick installation script
- **`DIGITALOCEAN.md`** - Comprehensive documentation and troubleshooting guide

### DigitalOcean App Platform
- **`.do/app.yaml`** - Configuration for DigitalOcean App Platform deployment
- **`Dockerfile.digitalocean`** - Optimized Dockerfile for App Platform

## Quick Start Options

### Option 1: Droplet Installation (Recommended)
For full control and customization:

```bash
curl -fsSL https://raw.githubusercontent.com/ShiningVenus/NodeBB/master/install-quick.sh | sudo bash -s yourdomain.com
```

### Option 2: App Platform Deployment
For managed hosting with automatic scaling:

1. Fork this repository
2. Create a new App on DigitalOcean App Platform
3. Connect your forked repository
4. Use the `.do/app.yaml` configuration file
5. Deploy and configure your database

## Features

### Droplet Installation Includes:
- ✅ Automated Docker setup
- ✅ Database configuration (MongoDB/PostgreSQL/Redis)
- ✅ Nginx reverse proxy with optimization
- ✅ Free SSL certificates with auto-renewal
- ✅ Firewall configuration
- ✅ Security hardening
- ✅ Automatic startup and monitoring
- ✅ Backup preparation

### App Platform Benefits:
- ✅ Managed infrastructure
- ✅ Automatic scaling
- ✅ Built-in monitoring
- ✅ Zero-downtime deployments
- ✅ Managed databases
- ✅ CDN integration

## Support

For detailed instructions, troubleshooting, and customization options, see [DIGITALOCEAN.md](DIGITALOCEAN.md).

## Requirements

- DigitalOcean account
- Domain name (for droplet installation)
- Ubuntu 20.04+ (for droplet installation)
- Minimum 2GB RAM recommended