# Terraform OpenStack RKE

**RKE** is a Terraform module useful for bootstraping **HA** kubernetes clusters using **k3s** and **rke2** on **OpenStack**

## Installation

Add the required configurations to your terraform config file and install module using command bellow:

```bash
terraform init
```

## Usage

```hcl
module "rke" {
  source = "cktf/rke/openstack"

  name       = "platform"
  type       = "k3s"
  registry   = "https://mirror.gcr.io"
  network_id = module.network.id
  masters = {
    linux = {
      name        = "Master1"
      count       = 1
      subnet      = "192.168.1.0/24"
      image_name  = "ubuntu"
      flavor_name = "m1.small"
      labels      = ["platform=linux"]
      taints      = []
    }
  }
  workers = {
    linux = {
      name        = "Master1"
      count       = 2
      subnet      = "192.168.2.0/24"
      image_name  = "ubuntu"
      flavor_name = "m1.small"
      labels      = ["platform=linux"]
      taints      = []
    }
  }
}

```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](mit)
