terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # vault = {
    #   source  = "hashicorp/vault"
    #   version = "~> 4.0"
    # }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "eef50188-7481-49ef-81c8-f6552808f870"
}

# provider "vault" {}