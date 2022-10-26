terraform {
  # backend "azurerm" {
  #   resource_group_name  = "terraform-pipeline"
  #   storage_account_name = "c2ctfpipelinewhzhyptv"
  #   container_name       = "terraform-state"
  #   key                  = "tfstate"

  #   use_azuread_auth = true
  # }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<= 2.78.0"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    jwt = {
      source  = "camptocamp/jwt"
      version = ">= 0.0.3"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    argocd = {
      source = "oboukili/argocd"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  required_version = ">= 0.13.0"
}
