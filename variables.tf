variable "name" {
  type        = string
  default     = ""
  sensitive   = false
  description = "Platform Name"
}

variable "network_id" {
  type        = string
  default     = ""
  sensitive   = false
  description = "Platform Network"
}

variable "masters" {
  type = map(object({
    count       = number
    subnet      = string
    image_name  = string
    flavor_name = string
  }))
  default     = {}
  sensitive   = false
  description = "Platform Masters"
}

variable "workers" {
  type = map(object({
    count       = number
    subnet      = string
    image_name  = string
    flavor_name = string
  }))
  default     = {}
  sensitive   = false
  description = "Platform Workers"
}
