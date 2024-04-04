output "k3-headnode-instance_public_ip" {
  value = crusoe_compute_instance.k3s_headnode[0].network_interfaces[0].public_ipv4.address
}

output "k3-ingress-instance_public_ip" {
  value = local.ingress_interface.public_ipv4.address
}
