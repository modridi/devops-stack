terraform {
  required_providers {
    argocd = {
      source = "oboukili/argocd"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.78.0"
    }
  }
}
