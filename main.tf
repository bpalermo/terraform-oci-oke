resource "oci_core_security_list" "control_plane" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "" ? "control-plane" : "${var.label_prefix}-control-plane"
  vcn_id         = var.vcn_id

  dynamic "egress_security_rules" {
    iterator = cp_egress_iterator
    for_each = local.cp_egress

    content {
      description      = cp_egress_iterator.value["description"]
      destination      = cp_egress_iterator.value["destination"]
      destination_type = cp_egress_iterator.value["destination_type"]
      protocol         = cp_egress_iterator.value["protocol"]
      stateless        = cp_egress_iterator.value["stateless"]

      dynamic "tcp_options" {
        for_each = cp_egress_iterator.value["protocol"] == local.tcp_protocol && cp_egress_iterator.value["port"] != -1 ? [1] : []

        content {
          min = cp_egress_iterator.value["port"]
          max = cp_egress_iterator.value["port"]
        }
      }

      dynamic "icmp_options" {
        for_each = cp_egress_iterator.value["protocol"] == local.icmp_protocol ? [1] : []

        content {
          type = 3
          code = 4
        }
      }
    }
  }

  dynamic "ingress_security_rules" {
    iterator = cp_ingress_iterator
    for_each = local.cp_ingress

    content {
      description = cp_ingress_iterator.value["description"]
      protocol    = cp_ingress_iterator.value["protocol"]
      source      = cp_ingress_iterator.value["source"]
      stateless   = cp_ingress_iterator.value["stateless"]

      dynamic "tcp_options" {
        for_each = cp_ingress_iterator.value["protocol"] == local.tcp_protocol && cp_ingress_iterator.value["port"] != -1 ? [1] : []

        content {
          min = cp_ingress_iterator.value["port"]
          max = cp_ingress_iterator.value["port"]
        }
      }

      dynamic "icmp_options" {
        for_each = cp_ingress_iterator.value["protocol"] == local.icmp_protocol ? [1] : []

        content {
          type = 3
          code = 4
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      egress_security_rules, ingress_security_rules
    ]
  }
}

resource "oci_core_subnet" "cp" {
  compartment_id = var.compartment_id

  vcn_id     = var.vcn_id
  cidr_block = local.cp_subnet

  display_name               = var.label_prefix == "" ? "control-plane" : "${var.label_prefix}-control-plane"
  dns_label                  = "cp"
  prohibit_public_ip_on_vnic = ! var.public_access
  route_table_id             = var.public_access ? var.ig_route_table_id : var.nat_route_table_id

  security_list_ids = [
    oci_core_security_list.control_plane.id
  ]
}

resource "oci_core_security_list" "workers" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "" ? "workers" : "${var.label_prefix}-workers"
  vcn_id         = var.vcn_id

  dynamic "egress_security_rules" {
    iterator = workers_egress_iterator
    for_each = local.workers_egress

    content {
      description      = workers_egress_iterator.value["description"]
      destination      = workers_egress_iterator.value["destination"]
      destination_type = workers_egress_iterator.value["destination_type"]
      protocol         = workers_egress_iterator.value["protocol"]
      stateless        = workers_egress_iterator.value["stateless"]

      dynamic "tcp_options" {
        for_each = workers_egress_iterator.value["protocol"] == local.tcp_protocol && workers_egress_iterator.value["port"] != -1 ? [1] : []

        content {
          min = workers_egress_iterator.value["port"]
          max = workers_egress_iterator.value["port"]
        }
      }

      dynamic "icmp_options" {
        for_each = workers_egress_iterator.value["protocol"] == local.icmp_protocol ? [1] : []

        content {
          type = 3
          code = 4
        }
      }
    }
  }

  dynamic "ingress_security_rules" {
    iterator = workers_ingress_iterator
    for_each = local.workers_ingress

    content {
      description = workers_ingress_iterator.value["description"]
      protocol    = workers_ingress_iterator.value["protocol"]
      source      = workers_ingress_iterator.value["source"]
      stateless   = workers_ingress_iterator.value["stateless"]

      dynamic "tcp_options" {
        for_each = workers_ingress_iterator.value["protocol"] == local.tcp_protocol && workers_ingress_iterator.value["port"] != -1 ? [1] : []

        content {
          min = workers_ingress_iterator.value["port"]
          max = workers_ingress_iterator.value["port"]
        }
      }

      dynamic "icmp_options" {
        for_each = workers_ingress_iterator.value["protocol"] == local.icmp_protocol ? [1] : []

        content {
          type = 3
          code = 4
        }
      }
    }
  }

  # NodePort access - TCP
  dynamic "ingress_security_rules" {
    for_each = var.allow_node_port_access ? [1] : []

    content {
      description = "allow tcp NodePorts access to workers"
      protocol    = local.tcp_protocol
      source      = local.anywhere
      stateless   = false

      tcp_options {
        max = local.node_port_max
        min = local.node_port_min
      }
    }
  }

  # NodePort access - UDP
  dynamic "ingress_security_rules" {
    for_each = var.allow_node_port_access ? [1] : []

    content {
      description = "allow udp NodePorts access to workers"
      protocol    = local.udp_protocol
      source      = local.anywhere
      stateless   = false

      udp_options {
        max = local.node_port_max
        min = local.node_port_min
      }
    }
  }

  # ssh access
  dynamic "ingress_security_rules" {
    for_each = var.bastion_subnet_cidr_block != "" ? [1] : []

    content {
      description = "allow ssh access to worker nodes through bastion"
      protocol    = local.tcp_protocol
      source      = var.bastion_subnet_cidr_block
      stateless   = false

      tcp_options {
        max = local.ssh_port
        min = local.ssh_port
      }
    }
  }

  lifecycle {
    ignore_changes = [
      egress_security_rules, ingress_security_rules
    ]
  }
}

resource "oci_core_subnet" "workers" {
  vcn_id                     = var.vcn_id
  cidr_block                 = local.worker_subnet
  compartment_id             = var.compartment_id
  display_name               = var.label_prefix == "" ? "workers" : "${var.label_prefix}-workers"
  dns_label                  = "workers"
  prohibit_public_ip_on_vnic = true
  route_table_id             = var.nat_route_table_id
  security_list_ids          = [oci_core_security_list.workers.id]
}

# internal load balancer security checklist
resource "oci_core_security_list" "int_lb" {

  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "" ? "int-lb" : "${var.label_prefix}-int-lb"
  vcn_id         = var.vcn_id

  egress_security_rules {
    description = "allow stateful egress to workers. required for NodePorts and load balancer http/tcp health checks"
    protocol    = local.all_protocols
    destination = local.worker_subnet
    stateless   = false
  }

  ingress_security_rules {
    description = "allow ingress only from the public lb subnet"
    protocol    = local.tcp_protocol
    source      = data.oci_core_vcn.this.cidr_block
    stateless   = false
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to egress_security_rules,
      # because Kubernetes will dynamically add new ones based on
      # LoadBalancer requirements
      egress_security_rules,
    ]
  }
}

resource "oci_core_subnet" "int_lb" {
  vcn_id                     = var.vcn_id
  cidr_block                 = local.int_lb_subnet
  compartment_id             = var.compartment_id
  display_name               = var.label_prefix == "" ? "int_lb" : "${var.label_prefix}-int_lb"
  dns_label                  = "intlb"
  prohibit_public_ip_on_vnic = true
  route_table_id             = var.nat_route_table_id
  security_list_ids = [
    oci_core_security_list.int_lb.id
  ]
}

resource "oci_core_security_list" "pub_lb" {
  compartment_id = var.compartment_id
  display_name   = var.label_prefix == "" ? "pub-lb" : "${var.label_prefix}-pub-lb"
  vcn_id         = var.vcn_id

  egress_security_rules {
    description = "allow stateful egress to workers. required for NodePorts and load balancer http/tcp health checks"
    protocol    = local.all_protocols
    destination = local.worker_subnet
    stateless   = false
  }

  egress_security_rules {
    description = "allow egress from public load balancer to private load balancer"
    protocol    = local.all_protocols
    destination = local.int_lb_subnet
    stateless   = false
  }

  # allow only from WAF
  dynamic "ingress_security_rules" {
    iterator = waf_iterator
    for_each = var.waf_enabled == true ? data.oci_waas_edge_subnets.waf_cidr_blocks[0].edge_subnets : []

    content {
      description = "allow public ingress only from WAF CIDR blocks"
      protocol    = local.tcp_protocol
      source      = waf_iterator.value.cidr
      stateless   = false
    }
  }

  # restrict by ports only
  dynamic "ingress_security_rules" {
    iterator = pub_lb_ingress_iterator
    for_each = var.waf_enabled == false ? var.public_lb_ports : []

    content {
      description = "allow public ingress from anywhere on specified ports"
      protocol    = local.tcp_protocol
      source      = local.anywhere
      tcp_options {
        min = pub_lb_ingress_iterator.value
        max = pub_lb_ingress_iterator.value
      }
      stateless = false
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to egress_security_rules,
      # because Kubernetes will dynamically add new ones based on
      # LoadBalancer requirements
      egress_security_rules,
    ]
  }
}

resource "oci_core_subnet" "pub_lb" {
  vcn_id                     = var.vcn_id
  cidr_block                 = local.pub_lb_subnet
  compartment_id             = var.compartment_id
  display_name               = var.label_prefix == "" ? "pub_lb" : "${var.label_prefix}-pub_lb"
  dns_label                  = "publb"
  prohibit_public_ip_on_vnic = false
  route_table_id             = var.ig_route_table_id
  security_list_ids = [
    oci_core_security_list.pub_lb.id
  ]
}

resource "oci_identity_dynamic_group" "kms" {
  count = var.kms.use != "" ? 1 : 0

  compartment_id = var.tenancy_id
  description    = "dynamic group to allow cluster to use kms"
  matching_rule  = "ALL {resource.type = 'cluster', resource.compartment.id = '${var.compartment_id}'}"
  name           = var.label_prefix == "" ? "oke-kms-cluster" : "${var.label_prefix}-oke-kms-cluster"

  lifecycle {
    ignore_changes = [
      matching_rule
    ]
  }
}

resource "oci_identity_policy" "kms" {
  count = var.kms.use != "" ? 1 : 0

  compartment_id = var.compartment_id
  description    = "policy to allow instances to allow dynamic group ${var.label_prefix}-oke-kms-cluster to use kms"
  name           = var.label_prefix == "" ? "oke-kms" : "${var.label_prefix}-oke-kms"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.kms[0].name} to use keys in compartment id ${var.compartment_id} where target.key.id = '${var.kms.key_id}'"
  ]
}

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  kubernetes_version = var.kubernetes_version

  name = var.label_prefix == "" ? var.cluster_name : "${var.label_prefix}-${var.cluster_name}"

  kms_key_id = var.kms.use ? var.kms.key_id : null
  vcn_id     = var.vcn_id

  endpoint_config {
    is_public_ip_enabled = var.public_access
    subnet_id            = oci_core_subnet.cp.id
  }

  dynamic "image_policy_config" {
    for_each = length(var.image_signing_keys) > 0 ? [1] : []

    content {
      is_policy_enabled = true

      dynamic "key_details" {
        iterator = signing_keys_iterator
        for_each = var.image_signing_keys

        content {
          kms_key_id = signing_keys_iterator.value
        }
      }
    }
  }

  options {
    service_lb_subnet_ids = [
      oci_core_subnet.pub_lb.id
    ]

    add_ons {
      is_kubernetes_dashboard_enabled = var.is_kubernetes_dashboard_enabled
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = var.is_pod_security_policy_enabled
    }

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }
}

resource "oci_containerengine_node_pool" "this" {
  for_each       = var.node_pools
  compartment_id = var.compartment_id

  cluster_id = oci_containerengine_cluster.this.id

  kubernetes_version = var.kubernetes_version
  name               = var.label_prefix == "" ? each.key : "${var.label_prefix}-${each.key}"

  ssh_public_key = var.ssh_public_key

  node_config_details {
    dynamic "placement_configs" {
      for_each = var.ad_names

      content {
        availability_domain = placement_configs.value
        subnet_id           = oci_core_subnet.workers.id
      }
    }

    # set quantity to a minimum of 1 to allow small clusters.
    size = max(1, each.value.pool_size)
  }

  node_shape = each.value.shape

  node_shape_config {
    ocpus         = max(1, each.value.ocpus)
    memory_in_gbs = each.value.memory
  }

  node_source_details {
    source_type             = each.value.source_type
    image_id                = each.value.image_id
    boot_volume_size_in_gbs = each.value.boot_volume_size
  }

  # do not destroy the node pool if the kubernetes version has changed as part of the upgrade
  lifecycle {
    ignore_changes = [
      kubernetes_version
    ]
  }
}
