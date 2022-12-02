# Requirements:
# * Subscription
# * DNS zone + already set up delegation if domain is registered elsewhere
# * Storage account + container for state file
# * Azure AD user with the following roles:
# ** Azure AD application administrator role
# ** Azure RM subscription contributor
# ** Azure RM storage account contributor role (refine)


variable "dns_zone" {
  type = object({
    name           = string
    resource_group = string
  })
  default = {
    name           = "is-internal.camptocamp.com"
    resource_group = "default"
  }
}

variable "cluster_name" {
  type    = string
  default = "blue"
}
