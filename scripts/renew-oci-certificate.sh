#!/bin/bash

# Let's Encrypt Certificate Renewal Script with DNS-01 Challenge
# This script renews Let's Encrypt certificates using DNS-01 challenge for wildcard domains

set -e

# Configuration
DOMAINS="${DOMAINS:-*.leecod.ing,leecod.ing}"
EMAIL="${EMAIL:-admin@leecod.ing}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"
CERT_PATH="/etc/letsencrypt/live"
LOAD_BALANCER_ID="${LOAD_BALANCER_ID}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if Certbot is installed and configured
check_certbot() {
    if ! command -v certbot &> /dev/null; then
        error "Certbot is not installed. Please install it first."
    fi
    
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        error "CLOUDFLARE_API_TOKEN environment variable is not set."
    fi
    
    # Setup Cloudflare credentials
    mkdir -p ~/.secrets/certbot
    echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > ~/.secrets/certbot/cloudflare.ini
    chmod 600 ~/.secrets/certbot/cloudflare.ini
    
    log "Certbot and Cloudflare DNS plugin are properly configured"
}

# Check if certificate needs renewal (renew if expires within 30 days)
check_renewal_needed() {
    log "Checking if certificate renewal is needed..."
    
    # Get the first domain (primary domain)
    PRIMARY_DOMAIN=$(echo "$DOMAINS" | cut -d',' -f1 | sed 's/\*\.//')
    CERT_FILE="$CERT_PATH/$PRIMARY_DOMAIN/fullchain.pem"
    
    if [ ! -f "$CERT_FILE" ]; then
        log "Certificate file not found. Initial certificate issuance needed."
        return 0
    fi
    
    # Check certificate expiry
    EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    THIRTY_DAYS_IN_SECONDS=$((30 * 24 * 60 * 60))
    
    if [ $((EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP)) -lt $THIRTY_DAYS_IN_SECONDS ]; then
        log "Certificate expires within 30 days. Renewal needed."
        return 0
    else
        log "Certificate is still valid for more than 30 days. No renewal needed."
        return 1
    fi
}

# Request or renew certificate using DNS-01 challenge
renew_certificate() {
    log "Requesting/Renewing Let's Encrypt certificate with DNS-01 challenge..."
    
    # Convert domains to certbot format
    DOMAIN_ARGS=""
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain" | xargs) # Trim whitespace
        DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
    done
    
    # Run certbot with DNS-01 challenge
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 60 \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --expand \
        $DOMAIN_ARGS \
        --cert-name "leecod.ing"
    
    if [ $? -eq 0 ]; then
        log "Certificate renewal/issuance completed successfully"
    else
        error "Certificate renewal/issuance failed"
    fi
}

# Update OCI Load Balancer with new certificate (if OCI is being used)
update_load_balancer_certificate() {
    if [ -z "$LOAD_BALANCER_ID" ]; then
        log "LOAD_BALANCER_ID not set. Skipping load balancer update."
        return 0
    fi
    
    log "Updating OCI Load Balancer certificate..."
    
    PRIMARY_DOMAIN=$(echo "$DOMAINS" | cut -d',' -f1 | sed 's/\*\.//')
    CERT_FILE="$CERT_PATH/$PRIMARY_DOMAIN/fullchain.pem"
    KEY_FILE="$CERT_PATH/$PRIMARY_DOMAIN/privkey.pem"
    
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        error "Certificate or key file not found after renewal"
    fi
    
    # Read certificate content
    CERT_CONTENT=$(cat "$CERT_FILE")
    KEY_CONTENT=$(cat "$KEY_FILE")
    
    # Update load balancer certificate
    oci lb certificate create \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --certificate-name "leecod-ing-$(date +%Y%m%d)" \
        --public-certificate "$CERT_CONTENT" \
        --private-key "$KEY_CONTENT" \
        --wait-for-state SUCCEEDED \
        --max-wait-seconds 300
    
    if [ $? -eq 0 ]; then
        log "Load balancer certificate updated successfully"
        
        # Update HTTPS listener to use new certificate
        update_https_listener "leecod-ing-$(date +%Y%m%d)"
    else
        warn "Failed to update load balancer certificate"
    fi
}

# Update HTTPS listener to use new certificate
update_https_listener() {
    local cert_name=$1
    
    log "Updating HTTPS listener to use new certificate..."
    
    # Get current listener configuration
    LISTENER_INFO=$(oci lb listener get \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --query 'data' 2>/dev/null || echo "null")
    
    if [ "$LISTENER_INFO" = "null" ]; then
        warn "HTTPS listener not found, skipping listener update"
        return
    fi
    
    # Update listener with new certificate
    oci lb listener update \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --default-backend-set-name "$(echo "$LISTENER_INFO" | jq -r '."default-backend-set-name"')" \
        --port 443 \
        --protocol HTTP \
        --ssl-configuration '{
            "certificateName": "'$cert_name'",
            "verifyPeerCertificate": false,
            "verifyDepth": 1
        }' \
        --wait-for-state SUCCEEDED \
        --max-wait-seconds 300
    
    log "HTTPS listener updated successfully"
}

# Main execution
main() {
    log "Starting Let's Encrypt certificate renewal process..."
    
    check_certbot
    
    if check_renewal_needed; then
        renew_certificate
        update_load_balancer_certificate
        log "Certificate renewal completed successfully"
    else
        log "Certificate renewal not needed"
    fi
}

# Run main function
main "$@"
