variable "name" {
  type        = string
  default     = ""
  sensitive   = false
  description = "RKE Name"
}

variable "type" {
  type        = string
  default     = "k3s"
  sensitive   = false
  description = "RKE Type"

  validation {
    condition     = contains(["k3s", "rke2"], var.type)
    error_message = "Valid values for `type` are (k3s, rke2)."
  }
}

variable "rke_version" {
  type        = string
  default     = ""
  sensitive   = false
  description = "RKE Version"
}

variable "channel" {
  type        = string
  default     = ""
  sensitive   = false
  description = "RKE Channel"
}

variable "registry" {
  type        = string
  default     = "https://registry.hub.docker.com"
  sensitive   = false
  description = "RKE Registry"
}

variable "disables" {
  type        = list(string)
  default     = []
  sensitive   = false
  description = "RKE Disables"
}

variable "network_id" {
  type        = string
  default     = ""
  sensitive   = false
  description = "RKE Network"
}

variable "masters" {
  type = map(object({
    name         = string
    count        = number
    subnet       = string
    image_name   = string
    flavor_name  = string
    pre_create   = string
    post_create  = string
    pre_destroy  = string
    post_destroy = string
    labels       = list(string)
    taints       = list(string)
  }))
  default     = {}
  sensitive   = false
  description = "RKE Masters"
}

variable "workers" {
  type = map(object({
    name         = string
    count        = number
    subnet       = string
    image_name   = string
    flavor_name  = string
    pre_create   = string
    post_create  = string
    pre_destroy  = string
    post_destroy = string
    labels       = list(string)
    taints       = list(string)
  }))
  default     = {}
  sensitive   = false
  description = "RKE Workers"
}

variable "windows_workers" {
  type = map(object({
    name         = string
    count        = number
    subnet       = string
    image_name   = string
    flavor_name  = string
    pre_create   = string
    post_create  = string
    pre_destroy  = string
    post_destroy = string
    labels       = list(string)
    taints       = list(string)
  }))
  default     = {}
  sensitive   = false
  description = "RKE Windows Workers"
}
