data "oci_core_vcn" "this" {
  vcn_id = var.vcn_id
}

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = oci_containerengine_cluster.this.id
}

data "oci_waas_edge_subnets" "waf_cidr_blocks" {
  count = var.waf_enabled ? 1 : 0
}

data "oci_core_services" "this" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
