# Copyright 2017, 2019, Oracle Corporation and/or affiliates.  All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  anywhere = "0.0.0.0/0"

  # subnet cidrs - used by subnets
  cp_subnet     = cidrsubnet(data.oci_core_vcn.this.cidr_block, var.new_bits_cp, var.net_num_cp)
  int_lb_subnet = cidrsubnet(data.oci_core_vcn.this.cidr_block, var.new_bits_int_lb, var.net_num_int_lb)
  pub_lb_subnet = cidrsubnet(data.oci_core_vcn.this.cidr_block, var.new_bits_pub_lb, var.net_num_pub_lb)
  worker_subnet = cidrsubnet(data.oci_core_vcn.this.cidr_block, var.new_bits_workers, var.net_num_workers)

  # oracle services network
  osn = lookup(data.oci_core_services.this.services[0], "cidr_block")

  # 1. get a list of available images for this cluster
  # 2. filter by version
  # 3. if more than 1 image found for this version, pick the latest
  node_pool_image_ids = data.oci_containerengine_node_pool_option.this.sources

  # protocols
  # # special OCI value for all protocols
  all_protocols = "all"
  # # IANA protocol numbers
  icmp_protocol = 1
  tcp_protocol  = 6
  udp_protocol  = 17

  ssh_port      = 22
  node_port_min = 30000
  node_port_max = 32767

  # control plane
  cp_egress = [
    {
      description      = "Allow Kubernetes control plane to communicate with OKE",
      destination      = local.osn
      destination_type = "SERVICE_CIDR_BLOCK"
      protocol         = local.tcp_protocol
      port             = 443
      stateless        = false
    },
    {
      description      = "Allow all traffic to worker nodes"
      destination      = local.worker_subnet
      destination_type = "CIDR_BLOCK"
      protocol         = local.tcp_protocol
      port             = -1
      stateless        = false
    },
    {
      description      = "Allow path discovery to worker nodes"
      destination      = local.worker_subnet
      destination_type = "CIDR_BLOCK"
      protocol         = local.icmp_protocol
      port             = -1
      stateless        = false
    },
  ]

  cp_ingress = [
    {
      description = "Allow worker nodes to control plane API endpoint communication"
      protocol    = local.tcp_protocol
      port        = 6443
      source      = local.worker_subnet
      stateless   = false
    },
    {
      description = "Allow worker nodes to control plane communication"
      protocol    = local.tcp_protocol
      port        = 12250
      source      = local.worker_subnet
      stateless   = false
    },
    {
      description = "Allow path discovery from worker nodes"
      protocol    = local.icmp_protocol
      port        = -1
      source      = local.worker_subnet
      stateless   = false
    },
    {
      description = "Allow external access to control plane API endpoint communication"
      protocol    = local.tcp_protocol
      port        = 6443
      source      = var.cluster_access_source
      stateless   = false
    },
  ]

  # workers
  workers_egress = [
    {
      description      = "Allow egress for all traffic to allow pods to communicate between each other on different worker nodes on the worker subnet",
      destination      = local.worker_subnet
      destination_type = "CIDR_BLOCK"
      protocol         = local.all_protocols
      port             = -1
      stateless        = false
    },
    {
      description      = "Allow path discovery",
      destination      = local.anywhere,
      destination_type = "CIDR_BLOCK",
      protocol         = local.icmp_protocol,
      port             = -1,
      stateless        = false
    },
    {
      description      = "Allow worker nodes to communicate with OKE",
      destination      = local.osn,
      destination_type = "SERVICE_CIDR_BLOCK",
      protocol         = local.tcp_protocol,
      port             = -1,
      stateless        = false
    },
    {
      description      = "Allow worker nodes to control plane API endpoint communication",
      destination      = local.cp_subnet,
      destination_type = "CIDR_BLOCK",
      protocol         = local.tcp_protocol,
      port             = 6443,
      stateless        = false
    },
    {
      description      = "Allow worker nodes to control plane communication",
      destination      = local.cp_subnet,
      destination_type = "CIDR_BLOCK",
      protocol         = local.tcp_protocol,
      port             = 12250,
      stateless        = false
    },
    {
      description      = "Allow worker nodes access to Internet. Required for getting container images or using external services",
      destination      = local.anywhere,
      destination_type = "CIDR_BLOCK",
      protocol         = local.tcp_protocol,
      port             = -1,
      stateless        = false
    }
  ]

  workers_ingress = [
    {
      description = "Allow ingress for all traffic to allow pods to communicate between each other on different worker nodes on the worker subnet",
      protocol    = local.all_protocols,
      port        = -1,
      source      = local.worker_subnet,
      stateless   = false
    },
    {
      description = "Allow control plane to communicate with worker nodes",
      protocol    = local.tcp_protocol,
      port        = -1,
      source      = local.cp_subnet,
      stateless   = false
    },
    {
      description = "Allow path discovery from worker nodes"
      protocol    = local.icmp_protocol,
      port        = -1,
      source      = local.anywhere,
      stateless   = false
    }
  ]
}
