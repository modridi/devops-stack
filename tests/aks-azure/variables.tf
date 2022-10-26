variable "platform_name" {
  type    = string
  default = "platform-x"
}

variable "dns_zone" {
  type    = string
  default = "is-internal.camptocamp.com"
}

variable "default_rg_location" {
  description = "Location of default resource group"
  type        = string
  default     = "Switzerland North"
}
