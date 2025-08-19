# Random string for storage account name uniqueness
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# -------------------------------------------------------------------------------------------------
# Resource Group
# -------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "retail-pipeline-rg"
  location = var.location
}

# -------------------------------------------------------------------------------------------------
# Storage Account
# -------------------------------------------------------------------------------------------------
module "etl_storage" {
  source                   = "./modules/storage"
  name                     = "retailpipelinestorage"
  rg                       = azurerm_resource_group.rg.name
  location                 = var.location
  is_hns_enabled           = true
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  containers               = []
}

module "sql_audit" {
  source                   = "./modules/storage"
  name                     = "retailpipelinesqlaudit"
  rg                       = azurerm_resource_group.rg.name
  location                 = var.location
  is_hns_enabled           = true
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  containers               = []
}

# -------------------------------------------------------------------------------------------------
# ADLS
# -------------------------------------------------------------------------------------------------
resource "azurerm_storage_data_lake_gen2_filesystem" "retail_lake" {
  name               = "retail"
  storage_account_id = module.etl_storage.id
}

resource "azurerm_storage_data_lake_gen2_path" "bronze" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "bronze"
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "customer_bronze" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "bronze/customer"
  resource           = "directory"
  depends_on         = [azurerm_storage_data_lake_gen2_path.bronze]
}

resource "azurerm_storage_data_lake_gen2_path" "product_bronze" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "bronze/product"
  resource           = "directory"
  depends_on         = [azurerm_storage_data_lake_gen2_path.bronze]
}

resource "azurerm_storage_data_lake_gen2_path" "store_bronze" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "bronze/store"
  resource           = "directory"
  depends_on         = [azurerm_storage_data_lake_gen2_path.bronze]
}

resource "azurerm_storage_data_lake_gen2_path" "transaction_bronze" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "bronze/transaction"
  resource           = "directory"
  depends_on         = [azurerm_storage_data_lake_gen2_path.bronze]
}

resource "azurerm_storage_data_lake_gen2_path" "silver" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "silver"
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "gold" {
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.retail_lake.name
  storage_account_id = module.etl_storage.id
  path               = "gold"
  resource           = "directory"
}

# -------------------------------------------------------------------------------------------------
# SQL Server Database
# -------------------------------------------------------------------------------------------------
resource "azurerm_mssql_server" "sql_server" {
  name                          = "retail-db-server-madmax"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
  administrator_login           = "madmax"
  administrator_login_password  = "Mohitdixit12345!"
}

resource "azurerm_mssql_database" "sql_server_db" {
  name        = "retail-db-madmax"
  server_id   = azurerm_mssql_server.sql_server.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name    = "S0"
  max_size_gb = 2
}

# ── Auditing to Storage ──────────────────────────────────────
resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id                               = azurerm_mssql_server.sql_server.id
  storage_endpoint                        = module.sql_audit.primary_blob_endpoint
  storage_account_access_key_is_secondary = false
  storage_account_access_key              = module.sql_audit.storage_account_access_key
  retention_in_days                       = 90
}

# -------------------------------------------------------------------------------------------------
# Databricks Workspace
# -------------------------------------------------------------------------------------------------
resource "azurerm_databricks_workspace" "retail_pipeline_databricks_workspace" {
  name                = "retail-pipeline-databricks-workspace"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "standard"

  tags = {
    Name = "retail-pipeline-databricks-workspace"
  }
}

# -------------------------------------------------------------------------------------------------
# Azure Data Factory
# -------------------------------------------------------------------------------------------------
resource "azurerm_data_factory" "etl_adf" {
  name                = "retail-pipeline-adf"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_data_factory_linked_service_azure_sql_database" "sql_database_linked_service" {
  name              = "sql-database-linked-service"
  data_factory_id   = azurerm_data_factory.etl_adf.id
  connection_string = "data source=serverhostname;initial catalog=master;user id=testUser;Password=test;integrated security=False;encrypt=True;connection timeout=30"
}

resource "azurerm_data_factory_dataset_azure_sql_table" "customers_dataset" {
  name              = "retail-customers"
  data_factory_id   = azurerm_data_factory.etl_adf.id
  linked_service_id = azurerm_data_factory_linked_service_azure_sql_database.sql_database_linked_service.id
}

resource "azurerm_data_factory_dataset_azure_sql_table" "products_dataset" {
  name              = "retail-products"
  data_factory_id   = azurerm_data_factory.etl_adf.id
  linked_service_id = azurerm_data_factory_linked_service_azure_sql_database.sql_database_linked_service.id
}

resource "azurerm_data_factory_dataset_azure_sql_table" "orders_dataset" {
  name              = "retail-store"
  data_factory_id   = azurerm_data_factory.etl_adf.id
  linked_service_id = azurerm_data_factory_linked_service_azure_sql_database.sql_database_linked_service.id
}