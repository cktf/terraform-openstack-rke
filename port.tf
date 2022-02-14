resource "openstack_networking_port_v2" "master" {
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

  name           = "${var.name}_master_${each.key}"
  network_id     = var.network_id
  admin_state_up = true

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.master[each.value.key].id
  }
}

resource "openstack_networking_port_v2" "worker" {
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

  name           = "${var.name}_worker_${each.key}"
  network_id     = var.network_id
  admin_state_up = true

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.worker[each.value.key].id
  }
}
