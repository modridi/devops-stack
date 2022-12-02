terraform {
  backend "azurerm" {
    resource_group_name  = "devops-stack-v1"
    storage_account_name = "devopsstackv1state"
    container_name       = "statefile"
    key                  = "tfstate"
  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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

  required_version = ">= 1.2.0"
}
