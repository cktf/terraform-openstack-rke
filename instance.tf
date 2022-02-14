resource "openstack_compute_instance_v2" "master" {
  for_each = {
    for item in flatten([
      for key, value in var.masters : [
        for index in range(value.count) : {
          key   = key
          value = value
          index = index
        }
      ]
    ]) : "${item.key}_${item.index}" => item
  }
  depends_on = [
    openstack_compute_keypair_v2.master,
    openstack_networking_secgroup_v2.master
  ]

  name            = "${var.name}_master_${each.key}"
  image_name      = each.value.value.image_name
  flavor_name     = each.value.value.flavor_name
  key_pair        = openstack_compute_keypair_v2.master[each.value.key].name
  security_groups = [openstack_networking_secgroup_v2.master.name]

  user_data = templatefile("${path.module}/config/master.sh", {
    type          = var.type
    version       = var.rke_version
    channel       = var.channel
    registry      = var.registry
    disables      = var.disables
    leader        = keys(var.masters)[0] == each.value.key && each.value.index == 0
    load_balancer = openstack_lb_loadbalancer_v2.master.vip_address
    token_id      = random_string.token_id.result
    token_secret  = random_string.token_secret.result
    master_token  = random_string.master_token.result
    worker_token  = random_string.worker_token.result
    node          = each.value
  })
  network {
    port = openstack_networking_port_v2.master[each.key].id
  }
}

resource "openstack_compute_instance_v2" "worker" {
  for_each = {
    for item in flatten([
      for key, value in var.workers : [
        for index in range(value.count) : {
          key   = key
          value = value
          index = index
        }
      ]
    ]) : "${item.key}_${item.index}" => item
  }
  depends_on = [
    openstack_compute_keypair_v2.worker,
    openstack_networking_secgroup_v2.worker
  ]

  name            = "${var.name}_worker_${each.key}"
  image_name      = each.value.value.image_name
  flavor_name     = each.value.value.flavor_name
  key_pair        = openstack_compute_keypair_v2.worker[each.value.key].name
  security_groups = [openstack_networking_secgroup_v2.worker.name]

  user_data = templatefile("${path.module}/config/worker.sh", {
    type          = var.type
    version       = var.rke_version
    channel       = var.channel
    registry      = var.registry
    disables      = var.disables
    load_balancer = openstack_lb_loadbalancer_v2.master.vip_address
    worker_token  = random_string.worker_token.result
    node          = each.value
  })
  metadata = {
    datacenter = "microstack"
    leader_ip  = "localhost"
  }

  network {
    port = openstack_networking_port_v2.worker[each.key].id
  }
}
