terraform {
  required_providers {
    crusoe = {
      source = "crusoecloud/crusoe"
    }
  }
}

locals {
  use_lb            = var.headnode_count > 1
  haproxy_local     = !local.use_lb ? "" : <<-EOT
    global
        log /dev/log local0
        log /dev/log local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

    defaults
        log global
        mode tcp
        timeout connect 5000
        timeout client 50000
        timeout server 50000

    frontend k3s_cluster
        bind *:6443
        mode tcp
        default_backend k3s_nodes

    backend k3s_nodes
        mode tcp
        balance roundrobin
        %{for index, instance in crusoe_compute_instance.k3s_headnode~}
        server k3s_node${index} ${instance.network_interfaces[0].private_ipv4.address}:6443 check
        %{endfor~}
  EOT
  headnode_entry    = local.use_lb ? one(crusoe_compute_instance.k3s_lb) : one(crusoe_compute_instance.k3s_headnode)
  ingress_interface = local.headnode_entry.network_interfaces[0]
  headnode_has_gpu  = strcontains(var.headnode_instance_type, "sxm-ib")
}


resource "crusoe_compute_instance" "k3s_lb" {
  count          = local.use_lb ? 1 : 0
  name           = "${var.instance_name_prefix}-k3s-lb"
  type           = var.headnode_instance_type
  ssh_key        = var.ssh_pubkey
  location       = var.deploy_location
  image          = var.headnode_image
  startup_script = file("${path.module}/k3haproxy-install.sh")

  provisioner "file" {
    content     = local.haproxy_local
    destination = "/tmp/haproxy.cfg"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "crusoe_compute_instance" "k3s_headnode" {
  count    = var.headnode_count
  name     = "${var.instance_name_prefix}-k3s-${count.index}"
  type     = var.headnode_instance_type
  ssh_key  = var.ssh_pubkey
  location = var.deploy_location
  image    = var.headnode_image
  startup_script = templatefile("${path.module}/k3install-headnode.sh.tftpl",
    {
      is_main_headnode = count.index == 0
      headnode_has_gpu = local.headnode_has_gpu
    }
  )
  host_channel_adapters = local.headnode_has_gpu ? [{ ib_partition_id = var.ib_partition_id }] : []


  provisioner "file" {
    source      = "${path.module}/k3-0-serve-token.py"
    destination = "/opt/k3-0-serve-token.py"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "terraform_data" "copy-k3-files" {
  depends_on = [local.headnode_entry]
  count      = var.headnode_count
  provisioner "file" {
    content     = jsonencode(crusoe_compute_instance.k3s_headnode[0])
    destination = "/root/k3-0-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = crusoe_compute_instance.k3s_headnode[count.index].network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
  provisioner "file" {
    content     = jsonencode(local.headnode_entry)
    destination = "/root/k3-lb-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = crusoe_compute_instance.k3s_headnode[count.index].network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }

}

resource "crusoe_compute_instance" "workers" {
  depends_on            = [local.headnode_entry]
  count                 = var.worker_count
  name                  = "${var.instance_name_prefix}-k3s-worker-${count.index}"
  type                  = var.worker_instance_type
  ssh_key               = var.ssh_pubkey
  location              = var.deploy_location
  image                 = var.worker_image
  startup_script        = file("${path.module}/k3install-worker.sh")
  host_channel_adapters = [{ ib_partition_id = var.ib_partition_id }]
  provisioner "file" {
    content     = jsonencode(crusoe_compute_instance.k3s_headnode[0])
    destination = "/root/k3-0-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }

  provisioner "file" {
    content     = jsonencode(local.headnode_entry)
    destination = "/root/k3-lb-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "crusoe_vpc_firewall_rule" "k3_rule" {
  network           = local.ingress_interface.network
  name              = "k3s-pub-access"
  action            = "allow"
  direction         = "ingress"
  protocols         = "tcp"
  source            = "0.0.0.0/0"
  source_ports      = "1-65535"
  destination       = "${local.ingress_interface.private_ipv4.address}/32"
  destination_ports = "6443"
}
