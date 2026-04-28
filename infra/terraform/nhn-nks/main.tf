locals {
  nks_labels = merge(
    {
      kube_tag                      = var.kubernetes_version
      availability_zone             = var.availability_zone
      node_image                    = var.node_image_id
      boot_volume_size              = tostring(var.boot_volume_size)
      boot_volume_type              = var.boot_volume_type
      cert_manager_api              = "True"
      ca_enable                     = var.cluster_autoscaler_enabled ? "True" : "False"
      master_lb_floating_ip_enabled = var.master_lb_floating_ip_enabled ? "True" : "False"
    },
    var.extra_labels
  )
}

resource "nhncloud_kubernetes_cluster_v1" "this" {
  name                = var.cluster_name
  cluster_template_id = "iaas_console"
  fixed_network       = var.fixed_network_id
  fixed_subnet        = var.fixed_subnet_id
  flavor_id           = var.worker_flavor_id
  keypair             = var.keypair_name
  node_count          = var.node_count
  labels              = local.nks_labels

  addons {
    name    = "calico"
    version = var.calico_version
    options = jsonencode({
      mode = var.calico_mode
    })
  }

  addons {
    name    = "coredns"
    version = var.coredns_version
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

