variable "tenancy_id" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "label_prefix" {
  type    = string
  default = ""
}

# region parameters
variable "ad_names" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "v1.20.8"
}

variable "public_access" {
  type    = bool
  default = false
}

variable "is_kubernetes_dashboard_enabled" {
  type    = bool
  default = false
}

variable "is_pod_security_policy_enabled" {
  type    = bool
  default = true
}

variable "vcn_id" {
  type = string
}

variable "image_signing_keys" {
  type    = list(string)
  default = []
}

variable "public_lb_ports" {
  type = list(string)
  default = [
    80,
    443
  ]
}

variable "ssh_public_key" {
  type = string
}

variable "ig_route_table_id" {
  type = string
}

variable "nat_route_table_id" {
  type = string
}

variable "bastion_subnet_cidr_block" {
  type    = string
  default = ""
}

variable "allow_node_port_access" {
  type    = bool
  default = false
}

variable "waf_enabled" {
  type    = bool
  default = false
}

variable "node_pools" {
  type = map(object({
    pool_size        = number
    shape            = string
    ocpus            = number
    memory           = number
    boot_volume_size = number
    source_type      = string
    image_id         = string
  }))
  default = {}
}

variable "kms" {
  type = object({
    use    = bool
    key_id = string
  })
  default = {
    use    = false
    key_id = ""
  }
  validation {
    condition     = ! (var.kms.use && (var.kms.key_id == null || var.kms.key_id == "")) || ! var.kms.use
    error_message = "The key_id is required if use is true."
  }
}

variable "net_num_cp" {
  type    = number
  default = 2
}

variable "net_num_int_lb" {
  type    = number
  default = 16
}

variable "net_num_pub_lb" {
  type    = number
  default = 17
}

variable "net_num_workers" {
  type    = number
  default = 1
}

variable "new_bits_cp" {
  type    = number
  default = 14
}

variable "new_bits_int_lb" {
  type    = number
  default = 11
}

variable "new_bits_pub_lb" {
  type    = number
  default = 11
}

variable "new_bits_workers" {
  type    = number
  default = 2
}

variable "cluster_access_source" {
  type    = string
  default = "0.0.0.0/0"
}

variable "pods_cidr" {
  type        = string
  default     = "10.244.0.0/16"
  description = "This is the CIDR range used for IP addresses by your pods. A /16 CIDR is generally sufficient. This CIDR should not overlap with any subnet range in the VCN (it can also be outside the VCN CIDR range)."
}

variable "services_cidr" {
  type        = string
  default     = "10.96.0.0/16"
  description = "This is the CIDR range used by exposed Kubernetes services (ClusterIPs). This CIDR should not overlap with the VCN CIDR range."
}
