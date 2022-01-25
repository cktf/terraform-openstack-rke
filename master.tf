data "openstack_networking_subnet_v2" "master" {
  for_each = var.masters

  network_id = var.network_id
  cidr       = each.value.subnet
}

resource "tls_private_key" "master" {
  for_each = var.masters

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "master" {
  for_each = var.masters

  name       = "${var.name}_master_${each.key}"
  public_key = tls_private_key.master[each.key].public_key_openssh
}

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

  })
  metadata = {
    datacenter = "microstack"
    leader_ip  = "localhost"
  }

  network {
    port = openstack_networking_port_v2.master[each.key].id
  }
}

# resource "openstack_networking_floatingip_v2" "this" {
#   pool = "external"
# }

# resource "openstack_compute_floatingip_associate_v2" "master" {
#   floating_ip = openstack_networking_floatingip_v2.this.address
#   instance_id = openstack_compute_instance_v2.this.id
# }
