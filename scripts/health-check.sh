#!/bin/bash

# Health Check Script for LibreChat
# This script checks if the LibreChat application is running properly

set -e

# Configuration
LIBRECHAT_URL="http://localhost:3080"
TIMEOUT=10
MAX_RETRIES=3

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
}

# Check if LibreChat is responding
check_librechat_health() {
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        log "Checking LibreChat health (attempt $((retries + 1))/$MAX_RETRIES)..."
        
        if curl -f -s --max-time $TIMEOUT "$LIBRECHAT_URL" > /dev/null 2>&1; then
            log "LibreChat is healthy and responding"
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            warn "Health check failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    error "LibreChat health check failed after $MAX_RETRIES attempts"
    return 1
}

# Check Docker containers
check_docker_containers() {
    log "Checking Docker container status..."
    
    # Check if docker-compose is running
    if ! docker-compose ps | grep -q "Up"; then
        error "No Docker containers are running"
        return 1
    fi
    
    # Check specific services
    local services=("librechat" "mongo" "rag_api")
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            log "Service $service is running"
        else
            error "Service $service is not running"
            return 1
        fi
    done
    
    return 0
}

# Check disk space
check_disk_space() {
    log "Checking disk space..."
    
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt 90 ]; then
        error "Disk usage is ${DISK_USAGE}% - critically high!"
        return 1
    elif [ "$DISK_USAGE" -gt 80 ]; then
        warn "Disk usage is ${DISK_USAGE}% - getting high"
    else
        log "Disk usage is ${DISK_USAGE}% - OK"
    fi
    
    return 0
}

# Check memory usage
check_memory_usage() {
    log "Checking memory usage..."
    
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$MEMORY_USAGE" -gt 90 ]; then
        error "Memory usage is ${MEMORY_USAGE}% - critically high!"
        return 1
    elif [ "$MEMORY_USAGE" -gt 80 ]; then
        warn "Memory usage is ${MEMORY_USAGE}% - getting high"
    else
        log "Memory usage is ${MEMORY_USAGE}% - OK"
    fi
    
    return 0
}

# Main health check function
main() {
    log "Starting comprehensive health check..."
    
    local exit_code=0
    
    # Run all health checks
    check_docker_containers || exit_code=1
    check_librechat_health || exit_code=1
    check_disk_space || exit_code=1
    check_memory_usage || exit_code=1
    
    if [ $exit_code -eq 0 ]; then
        log "All health checks passed successfully"
    else
        error "One or more health checks failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"
