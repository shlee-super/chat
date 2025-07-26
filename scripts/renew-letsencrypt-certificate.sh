#!/bin/bash

# Let's Encrypt Certificate Renewal Script with DNS-01 Challenge
# This script renews Let's Encrypt certificates using DNS-01 challenge for wildcard domains

set -e

# Configuration
DOMAINS="${DOMAINS:-*.leecod.ing,leecod.ing}"
EMAIL="${EMAIL:-admin@leecod.ing}"
OCI_CONFIG_FILE="${OCI_CONFIG_FILE:-~/.oci/config}"
OCI_PROFILE="${OCI_PROFILE:-DEFAULT}"
CERT_PATH="/etc/letsencrypt/live"
LOAD_BALANCER_ID="${LOAD_BALANCER_ID}"
CERTIFICATE_OCID="${CERTIFICATE_OCID}" # Existing certificate OCID in Certificate Service

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
    
    # Check if certbot-dns-oci plugin is available
    if ! pip list | grep -q "certbot-dns-oci"; then
        error "certbot-dns-oci plugin is not installed. Please install it first."
    fi
    
    # Check if OCI CLI is available
    if ! command -v oci &> /dev/null; then
        error "OCI CLI is not installed. Please install it first."
    fi
    
    # Check OCI configuration
    if [ ! -f "$OCI_CONFIG_FILE" ]; then
        error "OCI configuration file not found at $OCI_CONFIG_FILE"
    fi
    
    # Test OCI DNS access
    if ! oci dns zone list --compartment-id "$(oci iam compartment list --query 'data[0].id' --raw-output 2>/dev/null)" --limit 1 &> /dev/null; then
        error "Unable to access OCI DNS service. Please check your OCI configuration and permissions."
    fi
    
    log "Certbot and certbot-dns-oci plugin are properly configured"
}

# Check if certificate needs renewal (renew if expires within 30 days)
check_renewal_needed() {
    log "Checking if certificate renewal is needed..."
    
    # Force renewal if FORCE_RENEWAL is set
    if [ "$FORCE_RENEWAL" = "true" ]; then
        log "Force renewal requested. Skipping expiry check."
        return 0
    fi
    
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
    log "Requesting/Renewing Let's Encrypt certificate with DNS-01 challenge using certbot-dns-oci..."
    
    # Convert domains to certbot format
    DOMAIN_ARGS=""
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain" | xargs) # Trim whitespace
        DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
    done
    
    # Run certbot with certbot-dns-oci plugin
    certbot certonly \
        --dns-oci \
        --dns-oci-credentials "$OCI_CONFIG_FILE" \
        --dns-oci-propagation-seconds 60 \
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

# Update OCI Certificate Service with new certificate version
update_oci_certificate() {
    if [ -z "$LOAD_BALANCER_ID" ]; then
        log "LOAD_BALANCER_ID not set. Skipping certificate update."
        return 0
    fi
    
    log "Updating OCI Certificate Service..."
    
    PRIMARY_DOMAIN=$(echo "$DOMAINS" | cut -d',' -f1 | sed 's/\*\.//')
    CERT_FILE="$CERT_PATH/$PRIMARY_DOMAIN/fullchain.pem"
    KEY_FILE="$CERT_PATH/$PRIMARY_DOMAIN/privkey.pem"
    
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        error "Certificate or key file not found after renewal"
    fi
    
    # Read certificate files
    CERT_CONTENT=$(cat "$CERT_FILE")
    KEY_CONTENT=$(cat "$KEY_FILE")
    
    # Get compartment ID
    COMPARTMENT_ID=$(oci iam compartment list --query 'data[0].id' --raw-output 2>/dev/null)
    if [ -z "$COMPARTMENT_ID" ]; then
        error "Unable to get compartment ID"
    fi
    
    if [ -n "$CERTIFICATE_OCID" ]; then
        # Update existing certificate with new version
        log "Adding new version to existing certificate: $CERTIFICATE_OCID"
        
        CERT_VERSION_RESPONSE=$(oci certs-mgmt certificate-version create-certificate-version-by-importing-config \
            --certificate-id "$CERTIFICATE_OCID" \
            --version-name "v$(date +%Y%m%d-%H%M%S)" \
            --certificate-pem "$CERT_CONTENT" \
            --private-key-pem "$KEY_CONTENT" \
            --wait-for-state ACTIVE \
            --max-wait-seconds 300 \
            --query 'data."version-number"' \
            --raw-output)
        
        if [ $? -eq 0 ] && [ -n "$CERT_VERSION_RESPONSE" ]; then
            log "Certificate version created successfully: v$CERT_VERSION_RESPONSE"
            
            # Set new version as current
            set_current_certificate_version "$CERTIFICATE_OCID" "$CERT_VERSION_RESPONSE"
            
            # Clean up old certificate versions
            cleanup_old_certificate_versions
            
            # Update Load Balancer (if needed - usually automatic)
            verify_load_balancer_certificate "$CERTIFICATE_OCID"
        else
            error "Failed to create new certificate version"
        fi
    else
        # Create new certificate (first time setup)
        log "Creating new certificate in OCI Certificate Service"
        
        CERT_NAME="leecod-ing-wildcard"
        
        CERT_RESPONSE=$(oci certs-mgmt certificate create-certificate-by-importing-config \
            --compartment-id "$COMPARTMENT_ID" \
            --name "$CERT_NAME" \
            --description "Let's Encrypt wildcard certificate for *.leecod.ing and leecod.ing" \
            --certificate-pem "$CERT_CONTENT" \
            --private-key-pem "$KEY_CONTENT" \
            --wait-for-state ACTIVE \
            --max-wait-seconds 300 \
            --query 'data.id' \
            --raw-output)
        
        if [ $? -eq 0 ] && [ -n "$CERT_RESPONSE" ]; then
            log "Certificate created successfully in OCI Certificate Service"
            log "Certificate OCID: $CERT_RESPONSE"
            log "⚠️  Please set CERTIFICATE_OCID environment variable to: $CERT_RESPONSE"
            
            # Update Load Balancer to use the new certificate
            update_load_balancer_with_certificate "$CERT_RESPONSE"
        else
            error "Failed to create certificate in OCI Certificate Service"
        fi
    fi
}

# Set new certificate version as current
set_current_certificate_version() {
    local cert_ocid=$1
    local version_number=$2
    
    log "Setting certificate version $version_number as current..."
    
    oci certs-mgmt certificate-version update \
        --certificate-id "$cert_ocid" \
        --version-number "$version_number" \
        --stage CURRENT \
        --wait-for-state ACTIVE \
        --max-wait-seconds 300
    
    if [ $? -eq 0 ]; then
        log "Certificate version $version_number set as current successfully"
    else
        error "Failed to set certificate version $version_number as current"
    fi
}

# Verify Load Balancer is using the correct certificate
verify_load_balancer_certificate() {
    local cert_ocid=$1
    
    log "Verifying Load Balancer certificate configuration..."
    
    # Get current listener configuration
    LISTENER_INFO=$(oci lb listener get \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --query 'data."ssl-configuration"."certificate-ids"[0]' \
        --raw-output 2>/dev/null || echo "null")
    
    if [ "$LISTENER_INFO" = "$cert_ocid" ]; then
        log "Load Balancer is correctly using certificate: $cert_ocid"
    elif [ "$LISTENER_INFO" = "null" ]; then
        warn "HTTPS listener not found, creating new one..."
        create_https_listener "$cert_ocid"
    else
        log "Load Balancer is using different certificate, updating..."
        update_load_balancer_with_certificate "$cert_ocid"
    fi
}

# Update Load Balancer to use certificate from Certificate Service
update_load_balancer_with_certificate() {
    local cert_ocid=$1
    
    log "Updating Load Balancer to use certificate from Certificate Service..."
    
    # Get current listener configuration
    LISTENER_INFO=$(oci lb listener get \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --query 'data' 2>/dev/null || echo "null")
    
    if [ "$LISTENER_INFO" = "null" ]; then
        warn "HTTPS listener not found, creating new HTTPS listener"
        create_https_listener "$cert_ocid"
        return
    fi
    
    # Update listener with certificate from Certificate Service
    oci lb listener update \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --default-backend-set-name "$(echo "$LISTENER_INFO" | jq -r '."default-backend-set-name"')" \
        --port 443 \
        --protocol HTTPS \
        --ssl-configuration '{
            "certificateIds": ["'$cert_ocid'"],
            "verifyPeerCertificate": false,
            "verifyDepth": 5,
            "cipherSuiteName": "oci-default-ssl-cipher-suite-v1"
        }' \
        --wait-for-state SUCCEEDED \
        --max-wait-seconds 300
    
    if [ $? -eq 0 ]; then
        log "Load Balancer updated successfully to use certificate: $cert_ocid"
    else
        error "Failed to update Load Balancer with new certificate"
    fi
}
    
    log "Creating new HTTPS listener..."
    
    # Get backend set name (assume it's the default one)
    BACKEND_SET_NAME=$(oci lb backend-set list \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --query 'data[0].name' \
        --raw-output 2>/dev/null)
    
    if [ -z "$BACKEND_SET_NAME" ]; then
        error "No backend set found for Load Balancer"
    fi
    
    oci lb listener create \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --default-backend-set-name "$BACKEND_SET_NAME" \
        --port 443 \
        --protocol HTTPS \
        --ssl-configuration '{
            "certificateIds": ["'$cert_ocid'"],
            "verifyPeerCertificate": false,
            "verifyDepth": 5,
            "cipherSuiteName": "oci-default-ssl-cipher-suite-v1"
        }' \
        --wait-for-state SUCCEEDED \
        --max-wait-seconds 300
    
    log "HTTPS listener created successfully"
}

# Create HTTPS listener if it doesn't exist
create_https_listener() {
    local cert_ocid=$1
    
    log "Creating new HTTPS listener..."
    
    # Get backend set name (assume it's the default one)
    BACKEND_SET_NAME=$(oci lb backend-set list \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --query 'data[0].name' \
        --raw-output 2>/dev/null)
    
    if [ -z "$BACKEND_SET_NAME" ]; then
        error "No backend set found for Load Balancer"
    fi
    
    oci lb listener create \
        --load-balancer-id "$LOAD_BALANCER_ID" \
        --listener-name "https-listener" \
        --default-backend-set-name "$BACKEND_SET_NAME" \
        --port 443 \
        --protocol HTTPS \
        --ssl-configuration '{
            "certificateIds": ["'$cert_ocid'"],
            "verifyPeerCertificate": false,
            "verifyDepth": 5,
            "cipherSuiteName": "oci-default-ssl-cipher-suite-v1"
        }' \
        --wait-for-state SUCCEEDED \
        --max-wait-seconds 300
    
    log "HTTPS listener created successfully"
}
# Clean up old certificate versions (keep last 3)
cleanup_old_certificate_versions() {
    if [ -z "$CERTIFICATE_OCID" ]; then
        log "No certificate OCID provided, skipping version cleanup"
        return 0
    fi
    
    log "Cleaning up old certificate versions..."
    
    # Get all versions, sorted by creation time (newest first)
    OLD_VERSIONS=$(oci certs-mgmt certificate-version list \
        --certificate-id "$CERTIFICATE_OCID" \
        --query 'data[?stage!=`CURRENT`].{versionNumber:"version-number",timeCreated:"time-created"}' \
        --output json | jq -r 'sort_by(.timeCreated) | reverse | .[3:] | .[].versionNumber' 2>/dev/null)
    
    # Delete old versions (keep only the 3 most recent + current)
    if [ -n "$OLD_VERSIONS" ]; then
        echo "$OLD_VERSIONS" | while read -r version_number; do
            if [ -n "$version_number" ] && [ "$version_number" != "null" ]; then
                log "Deleting old certificate version: $version_number"
                oci certs-mgmt certificate-version delete \
                    --certificate-id "$CERTIFICATE_OCID" \
                    --version-number "$version_number" \
                    --force \
                    --wait-for-state DELETED \
                    --max-wait-seconds 300 || warn "Failed to delete certificate version $version_number"
            fi
        done
    else
        log "No old certificate versions to clean up"
    fi
}
}

# Main execution
main() {
    log "Starting Let's Encrypt certificate renewal process..."
    
    check_certbot
    
    if check_renewal_needed; then
        renew_certificate
        update_oci_certificate
        log "Certificate renewal completed successfully"
    else
        log "Certificate renewal not needed"
    fi
}

# Run main function
main "$@"
