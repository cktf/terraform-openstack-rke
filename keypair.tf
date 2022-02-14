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

resource "tls_private_key" "worker" {
  for_each = var.workers

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "worker" {
  for_each = var.workers

  name       = "${var.name}_worker_${each.key}"
  public_key = tls_private_key.worker[each.key].public_key_openssh
}
