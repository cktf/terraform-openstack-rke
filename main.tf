terraform {
  required_version = ">= 0.14.0"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.45.0"
    }
    k8sbootstrap = {
      source  = "nimbolus/k8sbootstrap"
      version = "~> 0.1.2"
    }
  }
}

data "openstack_networking_subnet_v2" "master" {
  for_each = var.masters

  network_id = var.network_id
  cidr       = each.value.subnet
}

data "openstack_networking_subnet_v2" "worker" {
  for_each = var.workers

  network_id = var.network_id
  cidr       = each.value.subnet
}

data "k8sbootstrap_auth" "this" {
  depends_on = [openstack_compute_instance_v2.master, openstack_compute_instance_v2.worker]

  server = "https://${openstack_lb_loadbalancer_v2.master.vip_address}:6443"
  token  = "${random_string.token_id.result}.${random_string.token_secret.result}"
}
