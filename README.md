# Terraform OpenStack rke2 module

**rke2** is a Terraform project defining the required resources for creating a `rke2` cluster in openstack

## Installation

Add the required configurations to your terraform config file and install module using command bellow:

```bash
terraform init
```

## Usage

```hcl
module "rke2" {
  source = "terraform-modules-openstack/terraform-openstack-rke2"
  providers = {
    openstack = openstack
  }

  name       = "platform"
  network_id = module.network.id
  masters = {
    linux = {
      count       = 1
      subnet      = "192.168.1.0/24"
      image_name  = "ubuntu"
      flavor_name = "m1.small"
    }
  }
  workers = {
    linux = {
      count       = 2
      subnet      = "192.168.2.0/24"
      image_name  = "ubuntu"
      flavor_name = "m1.small"
    }
  }
}
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT]()

---
