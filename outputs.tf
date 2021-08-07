output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "public_endpoint" {
  value = lookup(oci_containerengine_cluster.this.endpoints[0], "public_endpoint", "")
}

output "private_endpoint" {
  value = lookup(oci_containerengine_cluster.this.endpoints[0], "private_endpoint", "")
}

output "node_pool_ids" {
  value = { for pool in oci_containerengine_node_pool.this : pool.name => pool.id }
}

output "subnet_cp_id" {
  value = oci_core_subnet.cp.id
}

output "subnet_workers_id" {
  value = oci_core_subnet.workers.id
}

output "subnet_int_lb_id" {
  value = oci_core_subnet.int_lb.id
}

output "subnet_pub_lb_id" {
  value = oci_core_subnet.pub_lb.id
}
