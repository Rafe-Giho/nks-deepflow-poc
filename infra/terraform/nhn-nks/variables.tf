variable "nhncloud_user_name" {
  description = "NHN Cloud account ID."
  type        = string
}

variable "nhncloud_tenant_id" {
  description = "NHN Cloud tenant ID from API Endpoint settings."
  type        = string
}

variable "nhncloud_api_password" {
  description = "NHN Cloud API password."
  type        = string
  sensitive   = true
}

variable "nhncloud_auth_url" {
  description = "NHN Cloud identity endpoint."
  type        = string
  default     = "https://api-identity-infrastructure.nhncloudservice.com/v2.0"
}

variable "nhncloud_region" {
  description = "NHN Cloud region."
  type        = string
  default     = "KR1"

  validation {
    condition     = contains(["KR1", "KR2", "JP1"], var.nhncloud_region)
    error_message = "nhncloud_region must be one of KR1, KR2, JP1."
  }
}

variable "cluster_name" {
  description = "NKS cluster name."
  type        = string
  default     = "sidecarless-poc"
}

variable "fixed_network_id" {
  description = "NHN Cloud VPC network UUID."
  type        = string
}

variable "fixed_subnet_id" {
  description = "NHN Cloud VPC subnet UUID for the default worker node group."
  type        = string
}

variable "worker_flavor_id" {
  description = "Default worker node flavor UUID."
  type        = string
}

variable "node_image_id" {
  description = "NKS worker node base image UUID."
  type        = string
}

variable "keypair_name" {
  description = "Key pair name applied to the default worker node group."
  type        = string
}

variable "kubernetes_version" {
  description = "NKS Kubernetes version, for example v1.30.3."
  type        = string
  default     = "v1.30.3"
}

variable "availability_zone" {
  description = "Default worker node group availability zone."
  type        = string
  default     = "kr-pub-a"
}

variable "node_count" {
  description = "Initial default worker node count."
  type        = number
  default     = 2
}

variable "boot_volume_size" {
  description = "Default worker boot volume size in GB."
  type        = number
  default     = 50
}

variable "boot_volume_type" {
  description = "Default worker boot volume type."
  type        = string
  default     = "General HDD"
}

variable "cluster_autoscaler_enabled" {
  description = "Enable NKS cluster autoscaler for the default worker node group."
  type        = bool
  default     = false
}

variable "master_lb_floating_ip_enabled" {
  description = "Create public domain address for Kubernetes API endpoint. Requires external network/subnet labels."
  type        = bool
  default     = false
}

variable "calico_version" {
  description = "NKS Calico add-on version."
  type        = string
  default     = "v3.30.2-nks2"
}

variable "calico_mode" {
  description = "NKS Calico mode. Use ebpf for the Sidecarless PoC primary path."
  type        = string
  default     = "ebpf"

  validation {
    condition     = contains(["vxlan", "ebpf"], var.calico_mode)
    error_message = "calico_mode must be vxlan or ebpf."
  }
}

variable "coredns_version" {
  description = "NKS CoreDNS add-on version."
  type        = string
  default     = "1.8.4-nks2"
}

variable "extra_labels" {
  description = "Extra NKS cluster labels. Use for optional NHN settings such as external network IDs."
  type        = map(string)
  default     = {}
}
