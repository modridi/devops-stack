# Logs
# resource "azurerm_storage_account" "logs" {
#   name                     = "logsstorageisinternal"
#   resource_group_name      = azurerm_resource_group.default.name
#   location                 = azurerm_resource_group.default.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "azurerm_storage_container" "logs" {
#   name                 = "lokilogs"
#   storage_account_name = azurerm_storage_account.logs.name
# }
