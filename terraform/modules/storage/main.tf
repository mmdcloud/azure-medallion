resource "azurerm_storage_account" "storage_account" {
  name                     = var.name
  resource_group_name      = var.rg
  location                 = var.location
  account_tier             = var.account_tier
  account_kind = var.account_kind
  account_replication_type = var.account_replication_type
  is_hns_enabled = var.is_hns_enabled
}

resource "azurerm_storage_container" "container" {
  for_each              = { for idx, obj in var.containers : obj.name => obj }
  name                  = each.value.name
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = each.value.container_access_type
}