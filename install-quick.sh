#!/bin/bash

#############################################################################
# NodeBB DigitalOcean Quick Install
# 
# One-liner installation script for NodeBB on DigitalOcean
# 
# Usage: 
#   curl -fsSL https://raw.githubusercontent.com/ShiningVenus/NodeBB/master/install-quick.sh | bash -s yourdomain.com
#
# This script downloads and runs the full installation script
#############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if domain is provided
if [[ -z "$1" ]]; then
    print_error "Usage: $0 <domain>"
    print_error "Example: $0 forum.example.com"
    exit 1
fi

DOMAIN="$1"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_info "NodeBB Quick Install for DigitalOcean"
echo "======================================"
echo "Domain: $DOMAIN"
echo

# Download the full installation script
print_info "Downloading installation script..."
curl -fsSL https://raw.githubusercontent.com/ShiningVenus/NodeBB/master/install-digitalocean.sh -o /tmp/install-digitalocean.sh

if [[ ! -f /tmp/install-digitalocean.sh ]]; then
    print_error "Failed to download installation script"
    exit 1
fi

# Make it executable
chmod +x /tmp/install-digitalocean.sh

print_success "Installation script downloaded"

# Run the installation
print_info "Starting NodeBB installation..."
/tmp/install-digitalocean.sh "$DOMAIN"

# Clean up
rm -f /tmp/install-digitalocean.sh

print_success "Quick installation completed!"