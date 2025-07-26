variable "region" {
  description = "OCI Region"
  type        = string
  default     = "ap-seoul-1"
}

variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment"
  type        = string
}

variable "vcn_id" {
  description = "OCID of the VCN"
  type        = string
}

variable "public_subnet_id" {
  description = "OCID of the public subnet for load balancer"
  type        = string
}

variable "private_subnet_id" {
  description = "OCID of the private subnet for instances"
  type        = string
}

variable "instance_private_ip" {
  description = "Private IP address of the instance running LibreChat"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the certificate"
  type        = string
  default     = "chat.leecod.ing"
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "librechat"
}
