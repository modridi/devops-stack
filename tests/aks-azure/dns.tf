resource "azurerm_dns_cname_record" "wildcard" {
  name                = "*.apps"
  zone_name           = var.dns_zone.name
  resource_group_name = var.dns_zone.resource_group
  ttl                 = 300
  record              = format("%s-%s.%s.cloudapp.azure.com.", var.cluster_name, replace(var.dns_zone.name, ".", "-"), azurerm_resource_group.default.location)
}
