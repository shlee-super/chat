terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# Data sources
data "oci_identity_compartment" "main" {
  id = var.compartment_id
}

data "oci_core_vcn" "main" {
  vcn_id = var.vcn_id
}

data "oci_core_subnet" "public" {
  subnet_id = var.public_subnet_id
}

data "oci_core_subnet" "private" {
  subnet_id = var.private_subnet_id
}

# Certificate
resource "oci_certificates_management_certificate" "main" {
  certificate_config {
    config_type                       = "MANAGED"
    subject {
      common_name = var.domain_name
    }
    certificate_profile_type = "TLS_SERVER_OR_CLIENT"
    validity {
      time_of_validity_not_after = "2025-12-31T23:59:59.999Z"
    }
  }
  compartment_id = var.compartment_id
  name           = "${var.app_name}-certificate"
  description    = "TLS certificate for ${var.domain_name}"
}

# Load Balancer
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_id
  display_name   = "${var.app_name}-lb"
  shape          = "flexible"
  
  shape_details {
    maximum_bandwidth_in_mbps = 100
    minimum_bandwidth_in_mbps = 10
  }

  subnet_ids = [var.public_subnet_id]
  
  is_private = false
  
  defined_tags = {
    "Project" = var.app_name
  }
}

# Backend Set
resource "oci_load_balancer_backend_set" "main" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "${var.app_name}-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = 3080
    url_path          = "/"
    return_code       = 200
    interval_ms       = 30000
    timeout_in_millis = 3000
    retries           = 3
  }
}

# Backend (연결할 인스턴스)
resource "oci_load_balancer_backend" "main" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.main.name
  ip_address       = var.instance_private_ip
  port             = 3080
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

# HTTP Listener (HTTPS 리다이렉트용)
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.main.name
  port                     = 80
  protocol                 = "HTTP"

  rule_set_names = [oci_load_balancer_rule_set.redirect_to_https.name]
}

# HTTPS Listener
resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.main.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.main.certificate_name
    verify_peer_certificate = false
    verify_depth            = 1
  }
}

# Certificate for Load Balancer
resource "oci_load_balancer_certificate" "main" {
  load_balancer_id   = oci_load_balancer_load_balancer.main.id
  certificate_name   = "${var.app_name}-cert"
  ca_certificate     = ""
  private_key        = ""
  public_certificate = ""

  lifecycle {
    create_before_destroy = true
  }
}

# Rule Set for HTTPS Redirect
resource "oci_load_balancer_rule_set" "redirect_to_https" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "redirect-to-https"

  items {
    action = "REDIRECT"
    redirect_uri {
      protocol = "HTTPS"
      port     = 443
    }
    response_code = 301
  }
}
