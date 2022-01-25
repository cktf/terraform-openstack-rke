# resource "openstack_keymanager_secret_v1" "master" {
#   name                 = "${var.name}_master_token"
#   secret_type          = "passphrase"
#   payload_content_type = "text/plain"
# }

# resource "openstack_keymanager_secret_v1" "worker" {
#   name                 = "${var.name}_worker_token"
#   secret_type          = "passphrase"
#   payload_content_type = "text/plain"
# }

# resource "openstack_keymanager_container_v1" "tokens" {
#   name = "${var.name}_tokens"
#   type = "generic"

#   secret_refs {
#     name       = "${var.name}_master_token"
#     secret_ref = openstack_keymanager_secret_v1.master.secret_ref
#   }

#   secret_refs {
#     name       = "${var.name}_worker_token"
#     secret_ref = openstack_keymanager_secret_v1.worker.secret_ref
#   }
# }
