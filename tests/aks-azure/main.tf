data "azuread_client_config" "current" {
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "default" {
  name     = var.platform_name
  location = var.default_rg_location
}

resource "tls_private_key" "node_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
