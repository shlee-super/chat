output "load_balancer_ip" {
  description = "Public IP address of the load balancer"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

output "load_balancer_id" {
  description = "OCID of the load balancer"
  value       = oci_load_balancer_load_balancer.main.id
}

output "certificate_id" {
  description = "OCID of the certificate"
  value       = oci_certificates_management_certificate.main.id
}

output "certificate_name" {
  description = "Name of the certificate in load balancer"
  value       = oci_load_balancer_certificate.main.certificate_name
}
