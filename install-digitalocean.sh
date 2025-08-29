#!/bin/bash

#############################################################################
# NodeBB DigitalOcean Installation Script
# 
# This script automates the installation of NodeBB on a DigitalOcean droplet
# running Ubuntu 20.04 or later.
#
# Usage: bash install-digitalocean.sh [domain]
# Example: bash install-digitalocean.sh forum.example.com
#
# Requirements:
# - Fresh Ubuntu 20.04+ DigitalOcean droplet
# - Domain pointing to the droplet's IP address
# - At least 2GB RAM recommended
#############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
DOMAIN=""
EMAIL=""
DB_TYPE="mongodb"  # mongodb, postgres, or redis
NODEBB_PORT="4567"
HTTP_PORT="80"
HTTPS_PORT="443"
SSH_PORT="22"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to get user input
get_user_input() {
    if [[ -z "$1" ]]; then
        echo
        print_info "NodeBB DigitalOcean Installation Setup"
        echo "======================================"
        echo
        
        # Get domain
        while [[ -z "$DOMAIN" ]]; do
            read -p "Enter your domain name (e.g., forum.example.com): " DOMAIN
            if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_error "Invalid domain format. Please enter a valid domain."
                DOMAIN=""
            fi
        done
        
        # Get email for SSL certificates
        while [[ -z "$EMAIL" ]]; do
            read -p "Enter your email address for SSL certificates: " EMAIL
            if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_error "Invalid email format. Please enter a valid email address."
                EMAIL=""
            fi
        done
        
        # Get database type
        echo
        print_info "Choose database type:"
        echo "1) MongoDB (recommended, default)"
        echo "2) PostgreSQL"
        echo "3) Redis"
        read -p "Select database type [1-3, default: 1]: " db_choice
        
        case $db_choice in
            2) DB_TYPE="postgres" ;;
            3) DB_TYPE="redis" ;;
            *) DB_TYPE="mongodb" ;;
        esac
    else
        DOMAIN="$1"
        # Set default email based on domain
        EMAIL="admin@$DOMAIN"
        print_info "Using domain: $DOMAIN"
        print_info "Using email: $EMAIL (you can change this later)"
    fi
    
    print_info "Configuration:"
    echo "  Domain: $DOMAIN"
    echo "  Email: $EMAIL"
    echo "  Database: $DB_TYPE"
    echo
    read -p "Continue with installation? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
}

# Function to update system packages
update_system() {
    print_info "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git ufw software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    print_success "System packages updated"
}

# Function to install Docker
install_docker() {
    print_info "Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group if not root
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
    fi
    
    print_success "Docker installed successfully"
}

# Function to install Docker Compose (standalone)
install_docker_compose() {
    print_info "Installing Docker Compose..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose installed successfully"
}

# Function to configure firewall
configure_firewall() {
    print_info "Configuring firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (be careful not to lock yourself out)
    ufw allow $SSH_PORT/tcp
    
    # Allow HTTP and HTTPS
    ufw allow $HTTP_PORT/tcp
    ufw allow $HTTPS_PORT/tcp
    
    # Enable firewall
    ufw --force enable
    
    print_success "Firewall configured"
}

# Function to install and configure Nginx
install_nginx() {
    print_info "Installing and configuring Nginx..."
    
    apt-get install -y nginx
    
    # Create Nginx configuration for NodeBB
    cat > /etc/nginx/sites-available/nodebb << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL configuration (certificates will be added by Certbot)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    
    # Proxy configuration
    location / {
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        
        proxy_pass http://127.0.0.1:$NODEBB_PORT;
        proxy_redirect off;
        
        # Socket.IO support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Increase timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Handle static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://127.0.0.1:$NODEBB_PORT;
        proxy_cache_valid 200 1d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/nodebb /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    nginx -t
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    print_success "Nginx installed and configured"
}

# Function to install Certbot and get SSL certificate
install_ssl() {
    print_info "Installing SSL certificate with Let's Encrypt..."
    
    # Install Certbot
    apt-get install -y certbot python3-certbot-nginx
    
    # Get SSL certificate
    print_info "Obtaining SSL certificate for $DOMAIN..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
    
    # Set up automatic renewal
    systemctl enable certbot.timer
    
    print_success "SSL certificate installed and auto-renewal configured"
}

# Function to clone NodeBB repository
clone_nodebb() {
    print_info "Setting up NodeBB..."
    
    # Create nodebb user if it doesn't exist
    if ! id "nodebb" &>/dev/null; then
        useradd -r -s /bin/bash -d /opt/nodebb nodebb
    fi
    
    # Create directory and clone
    mkdir -p /opt/nodebb
    cd /opt/nodebb
    
    # Remove existing files if any
    rm -rf NodeBB
    
    # Clone the repository
    git clone https://github.com/ShiningVenus/NodeBB.git
    cd NodeBB
    
    # Set ownership
    chown -R nodebb:nodebb /opt/nodebb
    
    print_success "NodeBB repository cloned"
}

# Function to create Docker Compose configuration
create_docker_config() {
    print_info "Creating Docker configuration..."
    
    cd /opt/nodebb/NodeBB
    
    # Create .env file
    cat > .env << EOF
# NodeBB Configuration
NODEBB_URL=https://$DOMAIN
NODEBB_PORT=$NODEBB_PORT

# Database Configuration
DB_TYPE=$DB_TYPE
EOF

    # Create docker-compose override for production
    if [[ "$DB_TYPE" == "mongodb" ]]; then
        cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  nodebb:
    environment:
      - NODE_ENV=production
      - NODEBB_URL=https://$DOMAIN
      - NODEBB_DB=mongo
      - NODEBB_DB_HOST=mongo
      - NODEBB_DB_PORT=27017
      - NODEBB_DB_NAME=nodebb
      - NODEBB_DB_USER=nodebb
      - NODEBB_DB_PASSWORD=nodebb_secure_password_$(openssl rand -hex 16)
    ports:
      - "127.0.0.1:$NODEBB_PORT:4567"
    restart: unless-stopped
    depends_on:
      - mongo

  mongo:
    environment:
      MONGO_INITDB_ROOT_USERNAME: nodebb
      MONGO_INITDB_ROOT_PASSWORD: nodebb_secure_password_$(openssl rand -hex 16)
      MONGO_INITDB_DATABASE: nodebb
    restart: unless-stopped
    ports: []  # Don't expose MongoDB to the outside
EOF
    elif [[ "$DB_TYPE" == "postgres" ]]; then
        cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  nodebb:
    environment:
      - NODE_ENV=production
      - NODEBB_URL=https://$DOMAIN
      - NODEBB_DB=postgres
      - NODEBB_DB_HOST=postgres
      - NODEBB_DB_PORT=5432
      - NODEBB_DB_NAME=nodebb
      - NODEBB_DB_USER=nodebb
      - NODEBB_DB_PASSWORD=nodebb_secure_password_$(openssl rand -hex 16)
    ports:
      - "127.0.0.1:$NODEBB_PORT:4567"
    restart: unless-stopped
    depends_on:
      - postgres
    profiles:
      - postgres

  postgres:
    environment:
      POSTGRES_USER: nodebb
      POSTGRES_PASSWORD: nodebb_secure_password_$(openssl rand -hex 16)
      POSTGRES_DB: nodebb
    restart: unless-stopped
    ports: []  # Don't expose PostgreSQL to the outside
    profiles:
      - postgres
EOF
    fi
    
    # Create necessary directories
    mkdir -p .docker/{database/{mongo/data,redis,postgresql/data},build,public/uploads,config}
    
    # Set ownership
    chown -R nodebb:nodebb /opt/nodebb
    
    print_success "Docker configuration created"
}

# Function to deploy NodeBB
deploy_nodebb() {
    print_info "Deploying NodeBB..."
    
    cd /opt/nodebb/NodeBB
    
    # Build and start services
    if [[ "$DB_TYPE" == "postgres" ]]; then
        sudo -u nodebb docker-compose --profile postgres up -d --build
    elif [[ "$DB_TYPE" == "redis" ]]; then
        sudo -u nodebb docker-compose --profile redis up -d --build
    else
        sudo -u nodebb docker-compose up -d --build
    fi
    
    # Wait for services to be ready
    print_info "Waiting for services to start..."
    sleep 30
    
    # Check if NodeBB is running
    if curl -f http://localhost:$NODEBB_PORT > /dev/null 2>&1; then
        print_success "NodeBB is running on port $NODEBB_PORT"
    else
        print_warning "NodeBB might still be starting up. Check logs with: docker-compose logs nodebb"
    fi
    
    print_success "NodeBB deployed successfully"
}

# Function to create systemd service for Docker Compose
create_systemd_service() {
    print_info "Creating systemd service for NodeBB..."
    
    cat > /etc/systemd/system/nodebb.service << EOF
[Unit]
Description=NodeBB Forum
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nodebb/NodeBB
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
User=nodebb
Group=nodebb

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nodebb.service
    
    print_success "Systemd service created and enabled"
}

# Function to perform basic security hardening
security_hardening() {
    print_info "Applying basic security hardening..."
    
    # Disable root login and password authentication (if SSH keys are set up)
    if [[ -f /root/.ssh/authorized_keys || -f /home/*/.ssh/authorized_keys ]]; then
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        systemctl restart sshd
        print_success "SSH hardened (root login and password auth disabled)"
    else
        print_warning "No SSH keys found. Skipping SSH hardening to prevent lockout."
    fi
    
    # Set up automatic security updates
    apt-get install -y unattended-upgrades
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    
    print_success "Security hardening applied"
}

# Function to display final information
show_completion_info() {
    echo
    print_success "NodeBB installation completed successfully!"
    echo
    echo "============================================"
    echo "Installation Summary:"
    echo "============================================"
    echo "Domain: https://$DOMAIN"
    echo "Database: $DB_TYPE"
    echo "NodeBB Directory: /opt/nodebb/NodeBB"
    echo
    echo "Next Steps:"
    echo "1. Visit https://$DOMAIN to complete NodeBB setup"
    echo "2. Create your admin account through the web interface"
    echo "3. Configure your forum settings"
    echo
    echo "Useful Commands:"
    echo "- View logs: cd /opt/nodebb/NodeBB && docker-compose logs"
    echo "- Restart NodeBB: sudo systemctl restart nodebb"
    echo "- Update NodeBB: cd /opt/nodebb/NodeBB && git pull && docker-compose up -d --build"
    echo
    echo "SSL Certificate:"
    echo "- Auto-renewal is configured"
    echo "- Manual renewal: sudo certbot renew"
    echo
    print_warning "Remember to:"
    echo "- Change default database passwords"
    echo "- Configure your forum through the admin panel"
    echo "- Set up regular backups"
    echo "- Monitor your server resources"
    echo
}

# Main installation function
main() {
    echo "============================================"
    echo "NodeBB DigitalOcean Installation Script"
    echo "============================================"
    echo
    
    check_root
    get_user_input "$1"
    
    print_info "Starting installation process..."
    
    update_system
    install_docker
    install_docker_compose
    configure_firewall
    install_nginx
    install_ssl
    clone_nodebb
    create_docker_config
    deploy_nodebb
    create_systemd_service
    security_hardening
    
    show_completion_info
}

# Run main function with all arguments
main "$@"