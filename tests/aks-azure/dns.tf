resource "azurerm_dns_zone" "default" {
  name                = format("%s.%s", var.platform_name, var.domain)
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_dns_cname_record" "wildcard" {
  name                = "*.apps"
  zone_name           = azurerm_dns_zone.default.name
  resource_group_name = azurerm_resource_group.default.name
  ttl                 = 300
  record              = format("%s-%s.%s.cloudapp.azure.com.", var.platform_name, replace(azurerm_dns_zone.default.name, ".", "-"), azurerm_resource_group.default.location)
}
