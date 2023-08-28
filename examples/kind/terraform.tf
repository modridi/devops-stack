terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "~> 6"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2"
    }
  }
}
